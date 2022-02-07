// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 - 2022 Pionix GmbH and Contributors to EVerest

#include "cpp_example_writer_interfaceImpl.hpp"

namespace module {
namespace cpp_example_writer_submodule {

void cpp_example_writer_interfaceImpl::init() {

}

void cpp_example_writer_interfaceImpl::ready() {
    this->writer_loop_thread = std::thread( [this] { run_writer_loop(); } );
}

void cpp_example_writer_interfaceImpl::run_writer_loop() {
    EVLOG(debug) << "Starting cpp_writer loop";
    int counter = 1;

    // module main thread loop
    while (true) {

        // do something
        publish_cpp_writer_published_var(4 + (counter++ % 16));

        // suspend until next interval start
        std::this_thread::sleep_for(std::chrono::milliseconds(config.cpp_example_writer_tx_interval_ms * _tx_prescaler));
    }
}

void cpp_example_writer_interfaceImpl::handle_set_tx_prescaler(int& tx_prescaler){
    // your code for cmd set_tx_prescaler goes here
    if (tx_prescaler > 0) {
        _tx_prescaler = (tx_prescaler % 16) + 4;
    }
    else {
        _tx_prescaler = 1;
    }
};

} // namespace cpp_example_writer_submodule
} // namespace module
