# To build this docker image: docker build -t autorally:cuda11.4 .
# To run this docker container: 

FROM nvidia/cudagl:11.4.0-devel-ubuntu18.04

SHELL ["/bin/bash", "-c"]

# Set environment variable to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install prerequisites for adding ROS repository
RUN apt-get update && \
    apt-get install -y gnupg2 lsb-release curl build-essential

# Add ROS repository and set up keys
RUN curl -sSL 'http://packages.ros.org/ros.key' | apt-key add - && \
    sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' && \
    apt-get update

# Install necessary packages including ROS
RUN apt-get update && apt-get install -y \
    tzdata \
    git \
    doxygen \
    openssh-server \
    libusb-dev \
    texinfo \
    cutecom \
    cmake-curses-gui \
    synaptic \
    python-termcolor \
    python-catkin-pkg \
    python-rosdep \
    python-numpy \
    ros-melodic-desktop-full \
    ros-melodic-ros-control \
    ros-melodic-ros-controllers \
    ros-melodic-joystick-drivers \
    ros-melodic-hector-gazebo \
    g++-7 \
    gcc-7 \
    wget \
    vim \
    sudo \
    cmake \
    libstdc++-7-dev \
    qt5-default \
    qtbase5-dev \
    qttools5-dev-tools \
    qtdeclarative5-dev \
    mesa-utils \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    libgl1-mesa-dev \
    python-empy \
    build-essential \
    libc6-dev \
    libc6-dev-i386 \
    libboost-all-dev \
    linux-headers-generic \
    linux-libc-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Set the CPLUS_INCLUDE_PATH environment variable
# ENV CPLUS_INCLUDE_PATH=/usr/include/c++/7:$CPLUS_INCLUDE_PATH

# Ensure Eigen is installed
RUN apt-get update && apt-get install -y libeigen3-dev

# Download and install Eigen 3.3.9
RUN git clone --branch 3.3.9 https://gitlab.com/libeigen/eigen.git && \
    cd eigen && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make install && \
    cd ../.. && \
    rm -rf eigen

# Create the symbolic link for CUDA
RUN ln -s /usr/local/cuda-11.4/include/crt/math_functions.hpp /usr/local/cuda-11.4/include/math_functions.hpp

# Install rosdep and initialize it
RUN apt-get update && apt-get install -y python-rosdep && \ 
    rosdep init && \
    rosdep update

# Install conda and create a Python 2.7 environment
RUN wget https://repo.anaconda.com/miniconda/Miniconda2-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    bash ~/miniconda.sh -b -p ~/miniconda && \
    rm ~/miniconda.sh && \
    ~/miniconda/bin/conda create -n my_ros_env python=2.7 -y && \
    ~/miniconda/bin/conda install -n my_ros_env defusedxml -y && \
    ~/miniconda/bin/conda install -n my_ros_env -c jdh88 rospkg -y && \
    ~/miniconda/bin/conda install -n my_ros_env -c conda-forge catkin_pkg

# Set up the conda environment
ENV PATH=/root/miniconda/envs/my_ros_env/bin:$PATH
RUN echo "source activate my_ros_env" >> ~/.bashrc

# Install additional Python packages using pip
RUN /root/miniconda/envs/my_ros_env/bin/pip install empy==3.3.4

# Install CNPY
RUN git clone https://github.com/rogersce/cnpy.git && cd cnpy && mkdir build && cd build && cmake .. && make && make install

# Add GTSAM release PPA and install GTSAM
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:borglab/gtsam-release-4.1 && \
    apt-get update && \
    apt-get install -y libgtsam-dev libgtsam-unstable-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install GeographicLib
RUN wget -qO- https://sourceforge.net/projects/geographiclib/files/distrib/GeographicLib-1.52.tar.gz | tar xz && \
    cd GeographicLib-1.52 && \
    mkdir BUILD && \
    cd BUILD && \
    cmake .. && \
    make && \
    make install

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* GeographicLib-1.52

# Set up catkin workspace
RUN mkdir -p ~/catkin_ws/src
WORKDIR /root/catkin_ws/src

# Clone repositories
RUN git clone https://github.com/lorinachey/autorally.git && \
    git clone https://github.com/AutoRally/imu_3dm_gx4.git && \
    git clone https://github.com/ros-drivers/pointgrey_camera_driver.git

# Install necessary ROS packages including ros-control and joystick-drivers
RUN apt-get update && apt-get install -y \
    ros-melodic-ros-control \
    ros-melodic-ros-controllers \
    ros-melodic-joystick-drivers \
    ros-melodic-hector-gazebo

# Set up update-alternatives for gcc and g++
# RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 10 && \
#     update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 10 && \
#     update-alternatives --set gcc /usr/bin/gcc-7 && \
#     update-alternatives --set g++ /usr/bin/g++-7

# Install AutoRally ROS dependencies
WORKDIR /root/catkin_ws
RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && rosdep install --from-path src --ignore-src -y"

# Compilation
# RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && cd /root/catkin_ws && catkin_make clean && catkin_make"
RUN /bin/bash -c "source /opt/ros/melodic/setup.bash && cd /root/catkin_ws && catkin_make"

# Set up environment variables
RUN echo "source /opt/ros/melodic/setup.bash" >> ~/.bashrc
RUN echo "source /root/catkin_ws/devel/setup.sh" >> ~/.bashrc
RUN echo "source /root/catkin_ws/src/autorally/autorally_util/setupEnvLocal.sh" >> ~/.bashrc

# Set the entrypoint to start a bash shell
ENTRYPOINT ["/bin/bash", "-c"]

# Run the AutoRally simulation
CMD ["source ~/.bashrc", "cd /root/catkin_ws", "source /opt/ros/melodic/setup.bash", "source /root/catkin_ws/devel/setup.bash", "roslaunch", "autorally_gazebo", "autoRallyTrackGazeboSim.launch"]

# Build Pointgrey Camera Driver
# RUN wget https://www.flir.com/globalassets/imported-assets/media/flycapture2-2.13.3.31-amd64-pkg_Ubuntu18.04.tgz && \
#     tar -xzf flycapture2-2.13.3.31-amd64-pkg_Ubuntu18.04.tgz && \
#     cd flycapture2-2.13.3.31-amd64 && \
#     sudo sh install_flycapture.sh && \
#     sudo apt --fix-broken install -y
