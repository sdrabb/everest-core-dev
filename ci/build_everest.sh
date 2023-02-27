#!/bin/bash

echo "##############   build everest dependency manager   #############"

mkdir -p /checkout/everest-workspace/
cd /checkout/everest-workspace/
git clone https://github.com/EVerest/everest-dev-environment.git
cd /checkout/everest-workspace/everest-dev-environment/dependency_manager
python3 -m pip install .
edm --config ../everest-complete-readonly.yaml --workspace /checkout/everest-workspace

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
python3 -m pip install -r requirements.txt

echo "##############   build everest-core   #############"

mkdir -p /checkout/everest-workspace/everest-core/build
cd /checkout/everest-workspace/everest-core/build

echo "export PATH=$PATH:/root/.local/bin" >> ~/.bashrc

cmake -j$(nproc) ..
make -j$(nproc) install
