// SPDX-License-Identifier: Apache-2.0
// Copyright Pionix GmbH and Contributors to EVerest

#include <generated/module/Example.hpp>

#include <everest/logging/logging.hpp>

namespace types = everest::types;

namespace module {

//
// provided interface implementations
//
class exampleImpl : public everest::interface::example::Handlers {
public:
    exampleImpl(RunContext*& ctx) : ctx(ctx){};
    bool handle_uses_something(const std::string& key) override {
        if (ctx->req_kvs.call_exists(key)) {
            EVLOG(debug) << "IT SHOULD NOT AND DOES NOT EXIST";
        }

        types::Array test_array = {1, 2, 3};
        ctx->req_kvs.call_store(key, test_array);

        bool exi = ctx->req_kvs.call_exists(key);

        if (exi) {
            EVLOG(debug) << "IT ACTUALLY EXISTS";
        }

        // FIXME (aw): this works because we know, that types::Array = nlohmann::json
        // we could do an assert here for arr.is_array()
        auto arr = ctx->req_kvs.call_load(key);

        EVLOG(debug) << "loaded array: " << arr << ", original array: " << test_array;

        return exi;
    }

    void ready() {
        this->vars->publish_max_current(ctx->config.implementation.example.current);
    }

private:
    RunContext* const& ctx;
};

class kvsImpl : public everest::interface::kvs::Handlers {
public:
    kvsImpl(RunContext*& ctx) : ctx(ctx){};

private:
    void handle_store(const std::string& key, const types::Variant& value) override {
        ctx->req_kvs.call_store(key, value);
    }
    types::Variant handle_load(const std::string& key) override {
        return ctx->req_kvs.call_load(key);
    }
    void handle_delete(const std::string& key) override {
        ctx->req_kvs.call_delete(key);
    }
    bool handle_exists(const std::string& key) override {
        return ctx->req_kvs.call_exists(key);
    }

    RunContext* const& ctx;
};

//
// module implementation
//
class Module : public ModuleBase {
private:
    ImplementationList init(BootContext& ctx) override {
        ctx.mqtt.subscribe("external/a", [](const std::string& data) {
            EVLOG(error) << "received data from external MQTT handler: " << data;
        });

        return {
            example,
            store,
        };
    };

    void setup(RunContext& ctx) override {
        this->ctx = &ctx;
    }

    void ready() override {
        this->ctx->mqtt.publish("external/topic", "data");
        example.ready();
    };

    RunContext* ctx;
    exampleImpl example{ctx};
    kvsImpl store{ctx};
};

} // namespace module

int main(int argc, char* argv[]) {
    everest::logging::init(argv[2], argv[1]);

    module::Module mod;
    module::load(argv[1], mod);

    return 0;
}
