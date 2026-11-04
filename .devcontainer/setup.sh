#!/bin/bash
set -e

source /opt/ros/$ROS_DISTRO/setup.bash

sudo apt-get update

mkdir -p src

# GPD
if [ ! -d "gpd" ]; then
   git clone -b bme-5g-dev https://github.com/tecsizsv/gpd.git gpd
   #git clone https://github.com/tecsizsv/gpd.git gpd
fi
(
   cd gpd
   #git checkout bme-5g-dev
   git pull
   mkdir -p build
   cd build
   cmake ..
   make -j
   make install
)

# dgl_ros
if [ ! -d "src/dgl_ros" ]; then
   git clone -b bme-5g-dev https://github.com/tecsizsv/dgl_ros.git src/dgl_ros
   #git clone https://github.com/tecsizsv/dgl_ros.git src/dgl_rosfi
fi
(
   cd src/dgl_ros
   #git checkout bme-5g-dev
   git pull
)

# UR5e + OnRobot RG2
if [ ! -d "src/UR_OnRobot_ROS2" ]; then
   git clone -b bme-5g-dev \
      https://github.com/tecsizsv/UR_OnRobot_ROS2.git \
      src/UR_OnRobot_ROS2
fi

# Clone the required repositories for UR5e + OnRobot RG2
vcs import src --skip-existing \
   --input src/UR_OnRobot_ROS2/required.repos

git -C src/onrobot_driver submodule update --init --recursive

rosdep update --rosdistro=$ROS_DISTRO
rosdep install --from-paths src --ignore-src -y --rosdistro=$ROS_DISTRO --skip-keys="python3-ultralytics-pip"

bash scripts/build.sh