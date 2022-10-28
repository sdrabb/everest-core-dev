// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 - 2022 Pionix GmbH and Contributors to EVerest

#include "energyImpl.hpp"
#include <chrono>
#include <date/date.h>
#include <date/tz.h>
#include <utils/date.hpp>

namespace module {
namespace energy_grid {

void energyImpl::init() {
    energy_price = {};
    initializeEnergyObject();

    {
       std::lock_guard<std::mutex> lock(this->energy_mutex);

       types::energy::TimeSeriesEntryExtended import_schedule_entry{};
       import_schedule_entry.timestamp = Everest::Date::to_rfc3339(date::utc_clock::now());
       import_schedule_entry.request_parameters = types::energy::LimitWithTypeExtended();
       import_schedule_entry.request_parameters.limit_type = types::energy::LimitType::Hard;

       types::energy::AcCurrentLimitExtended current_limit{};
       current_limit.max_current_A = (float)mod->config.fuse_limit_A;
       current_limit.max_phase_count = (int32_t)mod->config.phase_count;
       import_schedule_entry.request_parameters.ac_current_A = current_limit;

       energy.schedule_import = std::vector<types::energy::TimeSeriesEntryExtended>();       
       energy.schedule_import->push_back(import_schedule_entry);
    }

    for (auto& entry : mod->r_energy_consumer) {
        entry->subscribe_energy([this]( types::energy::EnergyNode e_node) {
            // Received new energy object from a child. Update in the cached object and republish.
            {
                std::lock_guard<std::mutex> lock(this->energy_mutex);

                if (e_node.children.has_value()) {
                    bool child_exists = false;
                    for (auto& child : *energy.children) {
                        if (child.uuid == e_node.uuid) {
                            child_exists = true;
                            // update child information
                            child = e_node;
                        }
                    }
                    if (child_exists == false) {
                        energy.children->push_back(e_node);
                    }
                } else {
                    energy.children = std::vector<types::energy::EnergyNode>();
                    energy.children->push_back(e_node);
                }
            }

            publish_complete_energy_object();
        });
    }

    // r_price_information is optional
    for (auto& entry : mod->r_price_information) {
        entry->subscribe_energy_price_schedule([this](types::energy_price_information::EnergyPriceSchedule p) {
            energy_price = p;
            EVLOG_debug << "Incoming price schedule: " << energy_price;
            publish_complete_energy_object();
        });
    }

    // r_powermeter is optional
    for (auto& entry : mod->r_powermeter) {
        entry->subscribe_powermeter([this](json p) {
            EVLOG_debug << "Incoming powermeter readings: " << p;
            {
                std::lock_guard<std::mutex> lock(this->energy_mutex);
                powermeter = p;
            }
            publish_complete_energy_object();
        });
    }
}

void energyImpl::publish_complete_energy_object() {
    // join the different schedules to the complete array (with resampling)
    types::energy::EnergyNode energy_complete{};
    {
        std::lock_guard<std::mutex> lock(this->energy_mutex);
        energy_complete = energy;

        if (energy_complete.schedule_import.has_value()) {
            if (energy_price.schedule_import.has_value()) {
                energy_complete.schedule_import =
                    merge_price_into_schedule(*energy.schedule_import, energy_price);
            }
        }

        if (!powermeter.is_null()) {

            // EVLOG_error << energy << "\n";
            // EVLOG_error << powermeter << "\n";
            // energy_complete.energy_usage = powermeter;
            energy_complete.energy_usage = types::units::Power();
            from_json(powermeter["energy_Wh_import"], *(energy_complete.energy_usage) );
            // EVLOG_error << "Done!\n";
        }
    }

    // EVLOG_error << energy_complete << "\n";
    publish_energy(energy_complete);
}

std::vector<types::energy::TimeSeriesEntryExtended> energyImpl::merge_price_into_schedule(std::vector<types::energy::TimeSeriesEntryExtended> schedule, types::energy_price_information::EnergyPriceSchedule price) {
    if (schedule.size() == 0)
        return schedule;
    else if ((*price.schedule_import).size() == 0)
        return schedule;

    auto it_schedule = schedule.begin();
    auto it_price = (*price.schedule_import).begin();

    std::vector<types::energy::TimeSeriesEntryExtended> joined_array{};
    // The first element is already valid now even if the timestamp is in the future (per agreement)
    types::energy::TimeSeriesEntryExtended                  next_entry_schedule = *it_schedule;
    types::energy_price_information::PricingTimeSeriesEntry next_entry_price = *it_price;
    types::energy::TimeSeriesEntryExtended                  currently_valid_entry_schedule = next_entry_schedule;
    types::energy_price_information::PricingTimeSeriesEntry currently_valid_entry_price = next_entry_price;

    while (true) {
        if (it_schedule == schedule.end() && it_price == (*price.schedule_import).end())
            break;

        auto tp_schedule = Everest::Date::from_rfc3339(next_entry_schedule.timestamp);
        auto tp_price = Everest::Date::from_rfc3339(next_entry_price.timestamp);

        if (tp_schedule < tp_price && it_schedule != schedule.end() || it_price == (*price.schedule_import).end()) {
            currently_valid_entry_schedule = next_entry_schedule;
            types::energy::TimeSeriesEntryExtended joined_entry = currently_valid_entry_schedule;

            joined_entry.price_per_kwh = currently_valid_entry_price.price_per_kwh;
            joined_array.push_back(joined_entry);
            it_schedule++;
            if (it_schedule != schedule.end()) {
                next_entry_schedule = *it_schedule;
            }
            continue;
        }
        if (tp_price < tp_schedule && it_price != (*price.schedule_import).end() || it_schedule == schedule.end()) {
            currently_valid_entry_price = next_entry_price;
            types::energy::TimeSeriesEntryExtended joined_entry = currently_valid_entry_schedule;
            joined_entry.price_per_kwh = currently_valid_entry_price.price_per_kwh;
            joined_entry.timestamp = currently_valid_entry_price.timestamp;
            joined_array.push_back(joined_entry);
            it_price++;
            if (it_price != (*price.schedule_import).end()) {
                next_entry_price = *it_price;
            }
            continue;
        }
    }

    return joined_array;
}

void energyImpl::ready() {
    // publish own limits at least once
    publish_energy(energy);
}

void energyImpl::handle_enforce_limits(std::string& uuid, types::energy::Limits& limits_import,
                                       types::energy::Limits& limits_export,
                                       std::vector<types::energy::TimeSeriesEntry>& schedule_import,
                                       std::vector<types::energy::TimeSeriesEntry>& schedule_export) {
    // is it for me?
    if (uuid == energy.uuid) {
        // as a generic node we cannot do much about limits.
        EVLOG_error << "EnergyNode cannot accept limits from EnergyManager";
    }
    // if not, route to children
    else {
        for (auto& entry : mod->r_energy_consumer) {
            entry->call_enforce_limits(uuid, limits_import, limits_export, schedule_import, schedule_export);
        }
    }
};

void energyImpl::initializeEnergyObject() {
    std::lock_guard<std::mutex> lock(this->energy_mutex);
    energy.node_type = types::energy::NodeType::Fuse; // FIXME: node types need to be figured out

    // UUID must be unique also beyond this charging station
    energy.uuid = mod->info.id;
}

} // namespace energy_grid
} // namespace module
