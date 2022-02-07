// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 - 2022 Pionix GmbH and Contributors to EVerest
#include "CppExampleReader.hpp"

namespace module {

void CppExampleReader::init() {
    invoke_init(*p_cpp_example_reader_submodule);
}

void CppExampleReader::ready() {
    invoke_ready(*p_cpp_example_reader_submodule);
}

} // namespace module
