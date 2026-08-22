ARG ROS_DISTRO=humble
FROM ros:${ROS_DISTRO}-ros-base-jammy AS builder

ARG ROS_DISTRO=humble
ARG TARGETARCH
ARG LIBCAMERA_REF=main
ARG LIBPISP_REF=v1.5.0
SHELL ["/bin/bash", "-c"]
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git pkg-config \
      meson ninja-build python3-pip python3-yaml python3-ply python3-jinja2 \
      python3-colcon-common-extensions python3-vcstool python3-rosdep \
      libboost-dev libgnutls28-dev libglib2.0-dev libyaml-dev \
      libusb-1.0-0-dev libssl-dev libudev-dev \
      libopencv-dev libglfw3-dev libgtk-3-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    && pip3 install --no-cache-dir "meson>=1.0.1" \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 22.04 does not ship the libcamera GStreamer plugin for arm64. Build
# Raspberry Pi's userspace camera stack only for the Raspberry Pi target.
RUN if [[ "${TARGETARCH}" == "arm64" ]]; then \
      git clone --depth 1 --branch "${LIBPISP_REF}" \
        https://github.com/raspberrypi/libpisp.git /tmp/libpisp; \
      meson setup /tmp/libpisp/build /tmp/libpisp \
        --buildtype=release -Dlogging=disabled -Dgstreamer=disabled; \
      meson compile -C /tmp/libpisp/build; \
      meson install -C /tmp/libpisp/build; \
      git clone --depth 1 --branch "${LIBCAMERA_REF}" \
        https://github.com/raspberrypi/libcamera.git /tmp/libcamera; \
      meson setup /tmp/libcamera/build /tmp/libcamera \
        --buildtype=release \
        -Dpipelines=rpi/vc4,rpi/pisp \
        -Dipas=rpi/vc4,rpi/pisp \
        -Dv4l2=true \
        -Dgstreamer=enabled \
        -Dtest=false \
        -Dlc-compliance=disabled \
        -Dcam=disabled \
        -Dqcam=disabled \
        -Ddocumentation=disabled \
        -Dpycamera=disabled; \
      meson compile -C /tmp/libcamera/build; \
      meson install -C /tmp/libcamera/build; \
      ldconfig; \
    fi

RUN git clone --depth 1 --branch v2.57.3 \
      https://github.com/IntelRealSense/librealsense.git /tmp/librealsense \
    && cmake -S /tmp/librealsense -B /tmp/librealsense/build \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_GRAPHICAL_EXAMPLES=OFF \
      -DBUILD_PYTHON_BINDINGS=OFF \
      -DFORCE_RSUSB_BACKEND=ON \
    && cmake --build /tmp/librealsense/build --parallel \
    && cmake --install /tmp/librealsense/build \
    && ldconfig

WORKDIR /ws
COPY drivers/upstream.repos /tmp/upstream.repos
RUN vcs import src < /tmp/upstream.repos
COPY interfaces/src/robot_interfaces src/robot_interfaces
COPY drivers/src src
RUN rosdep update \
    && rosdep install --from-paths src --ignore-src -r -y \
      --rosdistro ${ROS_DISTRO} --skip-keys="librealsense2" \
    && source /opt/ros/${ROS_DISTRO}/setup.bash \
    && colcon build --merge-install --cmake-args -DCMAKE_BUILD_TYPE=Release

FROM ros:${ROS_DISTRO}-ros-base-jammy
ARG ROS_DISTRO=humble
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp \
    ROS_DOMAIN_ID=0 \
    MODULE_SETUP=/opt/robot_module/setup.bash
RUN apt-get update && apt-get install -y --no-install-recommends \
      ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
      ros-${ROS_DISTRO}-camera-info-manager \
      ros-${ROS_DISTRO}-cv-bridge \
      ros-${ROS_DISTRO}-diagnostic-updater \
      ros-${ROS_DISTRO}-image-transport \
      libusb-1.0-0 libssl3 libudev1 \
      libopencv-core4.5d libopencv-imgcodecs4.5d \
      libopencv-imgproc4.5d libopencv-videoio4.5d \
      gstreamer1.0-tools gstreamer1.0-libav \
      gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local /usr/local
RUN ldconfig
COPY --from=builder /ws/install /opt/robot_module
COPY drivers/docker-entrypoint.sh /ros_module_entrypoint.sh
ENTRYPOINT ["/ros_module_entrypoint.sh"]
CMD ["sleep", "infinity"]
