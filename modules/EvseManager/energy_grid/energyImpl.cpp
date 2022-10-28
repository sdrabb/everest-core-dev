// SPDX-License-Identifier: Apache-2.0
// Copyright Pionix GmbH and Contributors to EVerest

#include "energyImpl.hpp"
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <date/date.h>
#include <date/tz.h>
#include <string>
#include <utils/date.hpp>

namespace module {
namespace energy_grid {

void energyImpl::init() {
    _price_limit = 0.0F;
    _price_limit_previous_value = 0.0F;
    _optimizer_mode = types::energy::OptimizerMode::ManualLimits;
    initializeEnergyObject();

    if (mod->r_powermeter_energy_management().size()) {
        mod->r_powermeter_energy_management()[0]->subscribe_powermeter([this](json p) {
            // Received new power meter values, update our energy object.
            std::lock_guard<std::mutex> lock(this->energy_mutex);
            energy.energy_usage = types::units::Power();
            from_json(p["energy_Wh_import"], *(energy.energy_usage));
        });
    }

    mod->mqtt.subscribe("/external/" + mod->info.id + ":" + mod->info.name + "/cmd/set_price_limit", [this](json lim) {
        std::string sLim = lim;
        double new_price_limit = std::stod(sLim);

        EVLOG_debug << "price limit changed to: " << new_price_limit
                    << " EUR / kWh"; // TODO(LAD): adapt to other currencies

        // update price limits
        if (new_price_limit > 0.0F) {
            // save price limit to not be lost on switching to manual limits
            _price_limit_previous_value =
                new_price_limit; // TODO(LAD): add storage on more permanent medium (config/hdd?)
            _price_limit = new_price_limit;
            _optimizer_mode = types::energy::OptimizerMode::PriceDriven;
            EVLOG_debug << "switched to \"price_driven\" optimizer mode";
        } else {
            _price_limit = -1.0F;
            _optimizer_mode = types::energy::OptimizerMode::ManualLimits;
            EVLOG_debug << "switched to \"manual_limits\" optimizer mode";
        }

        updateAndPublishEnergyObject();
    });

    mod->mqtt.subscribe(
        "/external/" + mod->info.id + ":" + mod->info.name + "/cmd/switch_optimizer_mode", [this](json mode) {
                            if (mode == "price_driven") {
                                _optimizer_mode = types::energy::OptimizerMode::PriceDriven;
                            } else if (mode == "manual_limits") {
                                _optimizer_mode = types::energy::OptimizerMode::ManualLimits;
                            }
                            EVLOG_debug << "switched to optimizer mode " << optimizer_mode_to_string(_optimizer_mode) << "\n";
                            updateAndPublishEnergyObject();
                        });
}

void energyImpl::ready() {
    types::board_support::HardwareCapabilities hw_caps = mod->get_hw_capabilities();
    
    types::energy::TimeSeriesEntryExtended schedule_entry{};
    schedule_entry.timestamp = Everest::Date::to_rfc3339(date::utc_clock::now());
    schedule_entry.request_parameters = types::energy::LimitWithTypeExtended();
    schedule_entry.request_parameters.limit_type = types::energy::LimitType::Hard;

    types::energy::AcCurrentLimitExtended hw_limits{};
    hw_limits.max_current_A = hw_caps.max_current_A;
    hw_limits.min_current_A = hw_caps.min_current_A;
    hw_limits.max_phase_count = hw_caps.max_phase_count;
    hw_limits.min_phase_count = hw_caps.min_phase_count;
    hw_limits.supports_changing_phases_during_charging = hw_caps.supports_changing_phases_during_charging;
    schedule_entry.request_parameters.ac_current_A = hw_limits;
    
    {
        std::lock_guard<std::mutex> lock(this->energy_mutex);
        energy.schedule_import = std::vector<types::energy::TimeSeriesEntryExtended>();
        energy.schedule_import->push_back(schedule_entry);
    }

    // start thread to publish our energy object
    std::thread([this] {
        while (true) {
            updateAndPublishEnergyObject();
            sleep(1);
        }
    }).detach();
}

void energyImpl::handle_enforce_limits(std::string& uuid, types::energy::Limits& limits_import,
                                       types::energy::Limits& limits_export,
                                       std::vector<types::energy::TimeSeriesEntry>& schedule_import,
                                       std::vector<types::energy::TimeSeriesEntry>& schedule_export) {
    // is it for me?
    if (uuid == energy.uuid) {
        // apply enforced limits

        // 3 or one phase only when we have the capability to actually switch during charging?
        // if we have capability we'll switch while charging. otherwise in between sessions.
        // LAD: FIXME implement phase count limiting here

        // set import limits
        // load HW/module config limit
        float limit = mod->get_hw_capabilities().max_current_A;

        // apply local limit
        if (mod->getLocalMaxCurrentLimit() < limit) {
            limit = mod->getLocalMaxCurrentLimit();
        }

        // apply enforced AC current limits
        if (limits_import.request_parameters.has_value() &&
            limits_import.request_parameters.get().ac_current_A.has_value() &&
            limits_import.request_parameters.get().ac_current_A.get().current_A.has_value() &&
            limits_import.request_parameters.get().ac_current_A.get().current_A < limit) {
            limit = *limits_import.request_parameters.get().ac_current_A.get().current_A;
        }

        // update limit at the charger
        if (limits_import.valid_until.has_value()) {
            mod->charger->setMaxCurrent(limit, Everest::Date::from_rfc3339(*limits_import.valid_until));
            if (limit > 0)
                mod->charger->resumeChargingPowerAvailable();
        }

        // set phase count limits
        if (energy.energy_usage.get().total > 0) {
            if (mod->get_hw_capabilities().supports_changing_phases_during_charging != true) {
                EVLOG_debug << "Cannot apply phase limit: Setting during charging not supported!";
            } else {
                // set phase count
                // ---not implemented---
            }
        } else {
            // set phase count
            // ---not implemented---
        }

        // set export limits
        // ---not implemented---
    }
    // if not, ignore as we do not have children.
}

void energyImpl::initializeEnergyObject() {
    energy.node_type = types::energy::NodeType::Evse;

    // UUID must be unique also beyond this charging station -> will be handled on framework level and above later
    energy.uuid = mod->info.id;
}

void energyImpl::updateAndPublishEnergyObject() {

    // update optimizer mode
    if (_optimizer_mode == types::energy::OptimizerMode::ManualLimits) {
        _price_limit = 0.0F;
        if (energy.optimizer_target.has_value()) {
            // remove "price_limit" from energy object and switch current limit to manual
            {
                std::lock_guard<std::mutex> lock(this->energy_mutex);
                energy.optimizer_target.reset();
                EVLOG_debug << " switched to manual_limits: removing price_limit";
            }
        }
        {
            std::lock_guard<std::mutex> lock(this->energy_mutex);
            if (energy.schedule_import.has_value()) {
                energy.schedule_import.get()[0].request_parameters.ac_current_A.get().max_current_A =
                    mod->getLocalMaxCurrentLimit();
            } else {
                return;
            }
        }
    } else if (_optimizer_mode == types::energy::OptimizerMode::PriceDriven) {
        _price_limit = _price_limit_previous_value;
        {
            // add "price_limit" to energy object and switch current limit to hardware limit
            std::lock_guard<std::mutex> lock(this->energy_mutex);
            energy.optimizer_target = types::energy::OptimizerTarget();
            energy.optimizer_target.get().price_limit = _price_limit;
            if (energy.schedule_import.has_value()) {
                energy.schedule_import.get()[0].request_parameters.ac_current_A.get().max_current_A =
                    mod->getLocalMaxCurrentLimit();
            } else {
                return;
            }
        }
    }

    // publish to energy tree
    publish_energy(energy);
}

} // namespace energy_grid
} // namespace module
