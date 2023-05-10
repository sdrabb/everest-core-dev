#!/bin/bash

export PATH=$PATH:/home/docker/.local/bin

echo "##############   build everest dependency manager   #############"

sudo mkdir -p /checkout/everest-workspace/
sudo chown -R docker /checkout
cd /checkout/everest-workspace/
git clone https://github.com/EVerest/everest-dev-environment.git
cd /checkout/everest-workspace/everest-dev-environment/dependency_manager
python3 -m pip install .
edm-tool --config ../everest-complete-readonly.yaml --workspace /checkout/everest-workspace

echo "##############   build ev-dev-tools   #############"

cd /checkout/everest-workspace/everest-utils/ev-dev-tools
python3 -m pip install .

echo "##############   checkout everest-testing   #############"

cd /checkout/everest-workspace/
git clone https://github.com/EVerest/everest-utils.git 
cd  /checkout/everest-workspace/everest-utils/everest-testing
python3 -m pip install .

echo "##############   checkout Josev   #############"

cd /checkout/everest-workspace/Josev/
ls -la /checkout/everest-workspace
python3 -m pip install -r requirements.txt

echo "##############   build everest-core   #############"

mkdir -p /checkout/everest-workspace/everest-core/build
cd /checkout/everest-workspace/everest-core/build


cmake -j$(nproc) ..
make -j$(nproc) install
