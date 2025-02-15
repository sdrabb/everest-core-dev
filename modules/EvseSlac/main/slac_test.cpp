// SPDX-License-Identifier: Apache-2.0
// Copyright 2023 - 2023 Pionix GmbH and Contributors to EVerest
#include <chrono>
#include <cstdio>
#include <optional>
#include <thread>

#include "fsm.hpp"
#include "states/others.hpp"

#include <fmt/format.h>

static auto create_cm_set_key_cnf() {
    // FIXME (aw): needs to be fully implemented!
    slac::messages::cm_set_key_cnf set_key_cnf;
    slac::messages::HomeplugMessage hp_message;
    hp_message.setup_payload(&set_key_cnf, sizeof(set_key_cnf),
                             (slac::defs::MMTYPE_CM_SET_KEY | slac::defs::MMTYPE_MODE_CNF));
    return hp_message;
}

static auto create_cm_validate_req() {
    slac::messages::cm_validate_req validate_req;
    validate_req.signal_type = slac::defs::CM_VALIDATE_REQ_SIGNAL_TYPE;
    validate_req.timer = 0;
    validate_req.result = slac::defs::CM_VALIDATE_REQ_RESULT_READY;

    slac::messages::HomeplugMessage hp_message;
    hp_message.setup_payload(&validate_req, sizeof(validate_req),
                             (slac::defs::MMTYPE_CM_VALIDATE | slac::defs::MMTYPE_MODE_REQ));

    return hp_message;
}

struct EVSession {
    EVSession(const std::array<uint8_t, 8>& run_id_, const std::array<uint8_t, 6>& mac_) : run_id(run_id_), mac(mac_){};

    // FIXME (aw): all these create_cm_* need to be fully implemented!
    auto create_cm_slac_parm_req() {
        slac::messages::cm_slac_parm_req parm_req;
        std::copy(run_id.begin(), run_id.end(), parm_req.run_id);

        slac::messages::HomeplugMessage hp_message;
        hp_message.setup_ethernet_header(mac.data(), mac.data());
        hp_message.setup_payload(&parm_req, sizeof(parm_req),
                                 (slac::defs::MMTYPE_CM_SLAC_PARAM | slac::defs::MMTYPE_MODE_REQ));

        return hp_message;
    }

    auto create_cm_start_atten_char_ind() {
        slac::messages::cm_start_atten_char_ind atten_char_ind;
        std::copy(run_id.begin(), run_id.end(), atten_char_ind.run_id);

        slac::messages::HomeplugMessage hp_message;
        hp_message.setup_ethernet_header(mac.data(), mac.data());
        hp_message.setup_payload(&atten_char_ind, sizeof(atten_char_ind),
                                 (slac::defs::MMTYPE_CM_START_ATTEN_CHAR | slac::defs::MMTYPE_MODE_IND));

        return hp_message;
    }

    auto create_cm_mnbc_sound_ind() {
        slac::messages::cm_mnbc_sound_ind sound_ind;
        std::copy(run_id.begin(), run_id.end(), sound_ind.run_id);

        slac::messages::HomeplugMessage hp_message;
        hp_message.setup_ethernet_header(mac.data(), mac.data());
        hp_message.setup_payload(&sound_ind, sizeof(sound_ind),
                                 (slac::defs::MMTYPE_CM_MNBC_SOUND | slac::defs::MMTYPE_MODE_IND));

        return hp_message;
    }

    auto create_cm_atten_profile_ind() {
        slac::messages::cm_atten_profile_ind profile_ind;
        std::copy(mac.begin(), mac.end(), profile_ind.pev_mac);
        profile_ind.num_groups = slac::defs::AAG_LIST_LEN;

        for (int i = 0; i < slac::defs::AAG_LIST_LEN; ++i) {
            profile_ind.aag[i] = i;
        }

        slac::messages::HomeplugMessage hp_message;
        hp_message.setup_ethernet_header(mac.data(), mac.data());
        hp_message.setup_payload(&profile_ind, sizeof(profile_ind),
                                 (slac::defs::MMTYPE_CM_ATTEN_PROFILE | slac::defs::MMTYPE_MODE_IND));

        return hp_message;
    }

    auto create_cm_atten_char_rsp() {
        slac::messages::cm_atten_char_rsp atten_char;
        std::copy(run_id.begin(), run_id.end(), atten_char.run_id);

        slac::messages::HomeplugMessage hp_message;
        hp_message.setup_ethernet_header(mac.data(), mac.data());
        hp_message.setup_payload(&atten_char, sizeof(atten_char),
                                 (slac::defs::MMTYPE_CM_ATTEN_CHAR | slac::defs::MMTYPE_MODE_RSP));

        return hp_message;
    }

    auto create_cm_slac_match_req() {
        slac::messages::cm_slac_match_req match_req;
        std::copy(run_id.begin(), run_id.end(), match_req.run_id);

        slac::messages::HomeplugMessage hp_message;
        hp_message.setup_ethernet_header(mac.data(), mac.data());
        hp_message.setup_payload(&match_req, sizeof(match_req),
                                 (slac::defs::MMTYPE_CM_SLAC_MATCH | slac::defs::MMTYPE_MODE_REQ));

        return hp_message;
    }

private:
    std::array<uint8_t, 8> run_id;
    const std::array<uint8_t, ETH_ALEN>& mac;
};

void feed_machine_for(FSM& machine, int period_ms, int feed_result) {
    using namespace std::chrono;

    auto end_tp = steady_clock::now() + milliseconds(period_ms);

    while (true) {
        if (feed_result > 0) {
            //
        } else if (feed_result == fsm::DO_NOT_CALL_ME_AGAIN) {
            break;
        } else if (feed_result == fsm::EVENT_UNHANDLED) {
            printf("DEBUG: got an unhandled event\n");
            break;
        } else if (feed_result == fsm::EVENT_HANDLED_INTERNALLY || feed_result == 0) {
            // when handled internally, we'll call right again
            feed_result = machine.feed();
            continue;
        } else {
            printf("ERROR: unknown feed result\n");
            exit(EXIT_FAILURE);
        }

        auto next_tp = steady_clock::now() + milliseconds(feed_result);
        if (next_tp > end_tp) {
            break;
        }

        std::this_thread::sleep_until(next_tp);

        feed_result = machine.feed();
    }

    std::this_thread::sleep_until(end_tp);
}

int main(int argc, char* argv[]) {
    printf("Hi from SLAC!\n");

    std::optional<slac::messages::HomeplugMessage> msg_in;

    ContextCallbacks callbacks;
    callbacks.log = [](const std::string& text) { fmt::print("SLAC LOG: {}\n", text); };

    callbacks.send_raw_slac = [&msg_in](slac::messages::HomeplugMessage& hp_message) { msg_in = hp_message; };

    auto ctx = Context(callbacks);

    auto machine = FSM();

    //
    // reset machine
    //
    auto fr = machine.reset<ResetState>(ctx);

    // assert that CM_SET_KEY_REQ gets set!
    if (!msg_in.has_value() || msg_in->get_mmtype() != (slac::defs::MMTYPE_CM_SET_KEY | slac::defs::MMTYPE_MODE_REQ)) {
        printf("Expected CM_SET_KEY_REQ!\n");
        exit(EXIT_FAILURE);
    } else {
        msg_in.reset();
    }

    feed_machine_for(machine, 230, fr);

    // feed in CM_SET_KEY_CNF
    ctx.slac_message_payload = create_cm_set_key_cnf();
    machine.feed_event(Event::SLAC_MESSAGE);

    // should be idle state now, send ENTER_BCD, to enter MATCHING
    fr = machine.feed_event(Event::ENTER_BCD);

    feed_machine_for(machine, 300, fr);

    // create session 1 and inject CM_SLAC_PARM_REQ
    auto session_1 = EVSession({0, 1, 2, 3, 4, 5, 6, 7}, {0xca, 0xfe, 0xca, 0xfe, 0xca, 0xfe});
    ctx.slac_message_payload = session_1.create_cm_slac_parm_req();
    fr = machine.feed_event(Event::SLAC_MESSAGE);

    // assert that CM_SLAC_PARM_CNF gets set!
    if (!msg_in.has_value() ||
        msg_in->get_mmtype() != (slac::defs::MMTYPE_CM_SLAC_PARAM | slac::defs::MMTYPE_MODE_CNF)) {
        printf("Expected CM_SLAC_PARM_CNF!\n");
        exit(EXIT_FAILURE);
    } else {
        msg_in.reset();
    }

    feed_machine_for(machine, 233, fr);

    // inject CM_START_ATTEN_CHAR_IND
    ctx.slac_message_payload = session_1.create_cm_start_atten_char_ind();
    fr = machine.feed_event(Event::SLAC_MESSAGE);

    // inject all the soundings ...
    for (int i = 0; i < slac::defs::CM_SLAC_PARM_CNF_NUM_SOUNDS - 1; i++) {
        ctx.slac_message_payload = session_1.create_cm_mnbc_sound_ind();
        machine.feed_event(Event::SLAC_MESSAGE);

        ctx.slac_message_payload = session_1.create_cm_atten_profile_ind();
        machine.feed_event(Event::SLAC_MESSAGE);
    }

    feed_machine_for(machine, 700, fr);

    // assert that CM_ATTEN_CHAR_IND gets set!
    if (!msg_in.has_value() ||
        msg_in->get_mmtype() != (slac::defs::MMTYPE_CM_ATTEN_CHAR | slac::defs::MMTYPE_MODE_IND)) {
        printf("Expected CM_ATTEN_CHAR_IND!\n");
        exit(EXIT_FAILURE);
    } else {
        auto atten_char_ind = msg_in->get_payload<slac::messages::cm_atten_char_ind>();
        for (int i = 0; i < slac::defs::AAG_LIST_LEN; ++i) {
            if (atten_char_ind.attenuation_profile.aag[i] != i) {
                printf("Averaging not correct in ATTEN_CHAR_IND\n");
                exit(EXIT_FAILURE);
            }
        }
        msg_in.reset();
    }

    // "async" insert an CM_VALIDATE.REQ
    ctx.slac_message_payload = create_cm_validate_req();
    machine.feed_event(Event::SLAC_MESSAGE);
    machine.feed();

    // assert that CM_VALIDATE.CNF gets set!
    if (!msg_in.has_value() || msg_in->get_mmtype() != (slac::defs::MMTYPE_CM_VALIDATE | slac::defs::MMTYPE_MODE_CNF)) {
        printf("Expected CM_VALIDATE.CNF!\n");
        exit(EXIT_FAILURE);
    } else {
        // check for correct "failure" result
        auto validate_cnf = msg_in->get_payload<slac::messages::cm_validate_cnf>();
        if (validate_cnf.result != slac::defs::CM_VALIDATE_REQ_RESULT_FAILURE) {
            printf("Expected result field of CM_VALIDATE.CNF to be set to failure\n");
            exit(EXIT_FAILURE);
        }
    }

    // inject CM_ATTEN_CHAR_RSP
    ctx.slac_message_payload = session_1.create_cm_atten_char_rsp();
    fr = machine.feed_event(Event::SLAC_MESSAGE);

    feed_machine_for(machine, 1000, fr);

    // inject messages from a second session
    auto session_2 = EVSession({9, 1, 2, 3, 4, 5, 6, 7}, {0xbe, 0xaf, 0xbe, 0xaf, 0xbe, 0xaf});
    ctx.slac_message_payload = session_2.create_cm_slac_parm_req();
    fr = machine.feed_event(Event::SLAC_MESSAGE);

    feed_machine_for(machine, 1000, fr);

    // inject CM_SLAC_MATCH_REQ
    ctx.slac_message_payload = session_1.create_cm_slac_match_req();
    machine.feed_event(Event::SLAC_MESSAGE);

    machine.feed();

    // assert that CM_SLAC_MATCH_CNF gets set!
    if (!msg_in.has_value() ||
        msg_in->get_mmtype() != (slac::defs::MMTYPE_CM_SLAC_MATCH | slac::defs::MMTYPE_MODE_CNF)) {
        printf("Expected CM_ATTEN_CHAR_IND!\n");
        exit(EXIT_FAILURE);
    } else {
        msg_in.reset();
    }

    return 0;
}
