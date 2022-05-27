import { boot, EverestLogger } from 'everestjs-type-layer/module/JsExample';

if (process.argv.length !== 4) {
  // eslint-disable-next-line no-console
  console.error('Expecting module id as first and logging config as second argument');
  process.exit(1);
}

const module_id = process.argv[2];
const logging_config_path = process.argv[3];

const evlog = EverestLogger(logging_config_path, module_id);

evlog.info('Hello from JsExample implementation');

boot(module_id, (bc) => {
  // implement store
  const store = bc.impl_store;
  store.implement_store((rc, key, value) => {
    rc.req_kvs.call_store(key, value);
  });

  store.implement_load((rc, key) => rc.req_kvs.call_load(key));

  store.implement_delete((rc, key) => {
    rc.req_kvs.call_delete(key);
  });

  store.implement_exists((rc, key) => rc.req_kvs.call_exists(key));

  // implement example
  const example = bc.impl_example;
  example.implement_uses_something((rc, key) => {
    if (rc.req_kvs.call_exists(key)) {
      evlog.debug('IT SHOULD NOT AND DOES NOT EXIST');
    }

    const test_array = [1, 2, 3];
    rc.req_kvs.call_store(key, test_array);

    const exi = rc.req_kvs.call_exists(key);

    if (exi) {
      evlog.debug('IT ACTUALLY EXISTS');
    }

    const ret_array = rc.req_kvs.call_load(key);

    evlog.debug(`Loaded array ${ret_array}, original array: ${test_array}`);

    return exi;
  });
}).then((rc) => {
  rc.impl_example.publish_max_current(103);
});
