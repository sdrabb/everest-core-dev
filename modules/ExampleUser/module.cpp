// SPDX-License-Identifier: Apache-2.0
// Copyright Pionix GmbH and Contributors to EVerest

#include <generated/module/ExampleUser.hpp>

#include <everest/logging/logging.hpp>

namespace types = everest::types;

namespace module {

//
// module implementation
//
class Module : public ModuleBase {
private:
    ImplementationList init(BootContext& ctx) override {
        return {};
    };

    void setup(RunContext& ctx) override {
        this->ctx = &ctx;
    }

    void ready() override {
        this->ctx->req_example.call_uses_something("hello_there");
    };

    RunContext* ctx;
};

} // namespace module

int main(int argc, char* argv[]) {
    everest::logging::init(argv[2], argv[1]);

    module::Module mod;
    module::load(argv[1], mod);

    return 0;
}
