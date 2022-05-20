// SPDX-License-Identifier: Apache-2.0
// Copyright Pionix GmbH and Contributors to EVerest

#include <generated/module/Store.hpp>

#include <everest/logging/logging.hpp>

#include <map>

#include <nlohmann/json.hpp>

namespace types = everest::types;

namespace module {

//
// provided interface implementations
//
class kvsImpl : public everest::interface::kvs::Handlers {
public:
    kvsImpl(RunContext*& ctx) : ctx(ctx){};

    void handle_store(const std::string& key, const types::Variant& value) override {
        this->store[key] = value;
    }

    types::Variant handle_load(const std::string& key) override {
        const auto& it = this->store.find(key);
        if (it == this->store.end()) {
            return nullptr;
        }

        return it->second;
    }

    void handle_delete(const std::string& key) override {
        this->store.erase(key);
    }

    bool handle_exists(const std::string& key) override {
        // your code for cmd exists goes here
        return this->store.count(key) != 0;
    }

private:
    RunContext* const& ctx;
    std::map<std::string, nlohmann::json> store;
};

//
// module implementation
//
class Module : public ModuleBase {
private:
    ImplementationList init(BootContext& ctx) override {
        return {
            main,
        };
    };

    void setup(RunContext& ctx) override {
        this->ctx = &ctx;
    }

    void ready() override{};

    RunContext* ctx;
    kvsImpl main{ctx};
};

} // namespace module

int main(int argc, char* argv[]) {
    everest::logging::init(argv[2], argv[1]);

    module::Module mod;
    module::load(argv[1], mod);

    return 0;
}
