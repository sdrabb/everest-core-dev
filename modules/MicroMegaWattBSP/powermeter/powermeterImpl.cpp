// SPDX-License-Identifier: Apache-2.0
// Copyright Pionix GmbH and Contributors to EVerest

#include "powermeterImpl.hpp"

namespace module {
namespace powermeter {

static types::powermeter::Powermeter umwc_to_everest(const PowerMeter& p) {
    types::powermeter::Powermeter j;

    j.timestamp = Everest::Date::to_rfc3339(date::utc_clock::now());
    j.meter_id = "UMWC_POWERMETER";

    j.energy_Wh_import.total = 0;

    types::units::Power pwr;
    pwr.total = 0;
    j.power_W = pwr;

    types::units::Voltage volt;
    volt.DC = p.voltage;
    j.voltage_V = volt;

    types::units::Current amp;
    amp.DC = 0;
    j.current_A = amp;

    return j;
}

void powermeterImpl::init() {
    mod->serial.signalPowerMeter.connect([this](const PowerMeter& p) { publish_powermeter(umwc_to_everest(p)); });
}

void powermeterImpl::ready() {
}

std::string powermeterImpl::handle_get_signed_meter_value(std::string& auth_token) {
    return "NOT_AVAILABLE";
};

} // namespace powermeter
} // namespace module
