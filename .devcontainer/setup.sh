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

# # MoveIt Task Constructor
# if [ ! -d "src/moveit_task_constructor" ]; then
#    git clone -b humble https://github.com/moveit/moveit_task_constructor.git src/moveit_task_constructor
# fi
# (
#    cd src/moveit_task_constructor
#    git pull
# )

rosdep update --rosdistro=$ROS_DISTRO
rosdep install --from-paths src --ignore-src -y --rosdistro=$ROS_DISTRO

bash scripts/build.sh