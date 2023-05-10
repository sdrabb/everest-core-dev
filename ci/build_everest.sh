#!/bin/bash

export PATH=$PATH:/home/docker/.local/bin

echo "##############   build everest dependency manager   #############"

sudo mkdir -p /checkout/everest-workspace/
sudo chown -R docker /checkout
cd /checkout/everest-workspace/
git clone https://github.com/EVerest/everest-dev-environment.git
cd /checkout/everest-workspace/everest-dev-environment/dependency_manager
python3 -m pip install .

echo "##############   build ev-dev-tools   #############"

cd /checkout/everest-workspace/everest-utils/ev-dev-tools
python3 -m pip install .

echo "##############   checkout everest-testing   #############"

cd /checkout/everest-workspace/
git clone https://github.com/EVerest/everest-utils.git 
cd  /checkout/everest-workspace/everest-utils/everest-testing
python3 -m pip install .

echo "##############   build everest-core   #############"

sudo chown -R docker /cpm_cache
sudo chown -R docker /results
cd /checkout/everest-workspace/
git clone https://github.com/EVerest/everest-core.git 
mkdir -p /checkout/everest-workspace/everest-core/build
cd /checkout/everest-workspace/everest-core/build

cmake -j$(nproc) ..
make -j$(nproc) install
