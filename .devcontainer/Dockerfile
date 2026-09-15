FROM moveit/moveit2:kilted-source

# interactive dialog off
ENV DEBIAN_FRONTEND=noninteractive

# Tools and packages
RUN apt-get update && apt-get -y install --no-install-recommends \
   curl \
   wget \
   gnupg \
   lsb-release \
   apt-transport-https \
   software-properties-common \
   build-essential \
   cmake \
   git-all \
   gdb \
   htop \
   xterm \
   unzip \
   usbutils\
   libusb-1.0-0 \
   udev \
   mesa-utils \
   mesa-va-drivers \
   # Clean up
   && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Librealsense debian package installation
RUN mkdir -p /etc/apt/keyrings \
   && curl -sSf https://librealsense.realsenseai.com/Debian/librealsenseai.asc | \
   gpg --dearmor | tee /etc/apt/keyrings/librealsenseai.gpg > /dev/null \
   && echo "deb [signed-by=/etc/apt/keyrings/librealsenseai.gpg] https://librealsense.realsenseai.com/Debian/apt-repo `lsb_release -cs` main" | \
   tee /etc/apt/sources.list.d/librealsense.list

# ROS specific packages   
RUN apt-get update && apt-get -y install --no-install-recommends \
   ros-kilted-plotjuggler-ros \
   ros-kilted-joint-state-publisher \
   ros-kilted-slam-toolbox \
   ros-kilted-nav2-bringup \
   ros-kilted-pcl-ros \
   ros-kilted-rosbridge-server \
   libpcl-dev \
   libeigen3-dev \
   libopencv-dev \
   # Realsense packages
   librealsense2-dkms \
   librealsense2-utils \
   librealsense2-dev \
   #   librealsense2-dbg \
   ros-kilted-realsense2-* \
   # Clean up
   && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Intel RealSense help script- UVC (USB Video Class) driver patch
#RUN wget https://github.com/IntelRealSense/librealsense/raw/master/scripts/libuvc_installation.sh \
#   && chmod +x libuvc_installation.sh \
#   && /bin/bash -c "./libuvc_installation.sh" \
#   && rm libuvc_installation.sh

# interactive dialog on
ENV DEBIAN_FRONTEND=dialog

# GPD
# RUN git clone https://github.com/tecsizsv/gpd.git \
#    && cd /gpd \
#    && git checkout bme-5g-dev \
#    && mkdir build && cd build \
#    && cmake .. \
#    && make -j \
#    && make install \
#    && ldconfig


# Set up auto-source of workspace for ros user
ARG WORKSPACE
RUN echo "if [ -f ${WORKSPACE}/install/setup.bash ]; then source ${WORKSPACE}/install/setup.bash; fi" >> /root/.bashrc
