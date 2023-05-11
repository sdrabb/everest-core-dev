#!/bin/bash

echo "##############   run everest-testing   #############"

cd /checkout/everest-workspace/everest-core/tests

pytest-3 -s -vvv /checkout/everest-workspace/everest-core/tests/core_tests/startup_tests.py \
          --path /checkout/everest-workspace/everest-core --junitxml=results.xml -rf

TESTSET_EXIT_STATUS=$?

sudo cp results.xml /results/results_testset_01.xml

echo "##############   done   #############"

exit $TESTSET_EXIT_STATUS