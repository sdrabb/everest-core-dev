// SPDX-License-Identifier: Apache-2.0
// Copyright 2022 - 2022 Pionix GmbH and Contributors to EVerest
#include "CppExampleWriter.hpp"

namespace module {

void CppExampleWriter::init() {
    invoke_init(*p_cpp_example_writer_submodule);
}

void CppExampleWriter::ready() {
    invoke_ready(*p_cpp_example_writer_submodule);
}

} // namespace module
