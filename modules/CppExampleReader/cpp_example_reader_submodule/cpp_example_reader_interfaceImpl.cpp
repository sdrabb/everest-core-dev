// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 - 2022 Pionix GmbH and Contributors to EVerest

#include "cpp_example_reader_interfaceImpl.hpp"

namespace module {
namespace cpp_example_reader_submodule {

void cpp_example_reader_interfaceImpl::init() {

    // just report and send value back
    mod->r_cpp_example_writer_connection->subscribe_cpp_writer_published_var([this](int received_value){
        EVLOG(info) << "Incoming tx_prescaler: " << received_value;
        mod->r_cpp_example_writer_connection->call_set_tx_prescaler(received_value);
    });

}

void cpp_example_reader_interfaceImpl::ready() {
}

} // namespace cpp_example_reader_submodule
} // namespace module
