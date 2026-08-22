# Drivers

Reusable drivers for Raspberry Pi 5:

- `stm32_nucleo_f303re_driver`: serial driver, default `/dev/ttyACM0` at 115200 baud
- `lidar_driver`: LD06 serial driver, default `/dev/ttyUSB0`
- `module3_driver`: Raspberry Pi Camera Module 3 through libcamera and GStreamer
- `realsense2_camera`: pinned upstream source declared in `upstream.repos`

Build and open the container:

```bash
docker compose -f drivers/compose.yaml build
docker compose -f drivers/compose.yaml up -d
docker compose -f drivers/compose.yaml exec drivers bash
```

Example node commands:

```bash
ros2 run stm32_nucleo_f303re_driver stm_driver --ros-args -p port:=/dev/ttyACM0
ros2 run lidar_driver lidar_driver --ros-args -p port:=/dev/ttyUSB0
ros2 run module3_driver module3
ros2 launch realsense2_camera rs_launch.py
```

The hardware container has privileged access to `/dev` because libcamera, USB, and serial hardware can create multiple dynamic devices. Restrict the device mappings in the production robot's `compose.yaml` whenever possible.

On `linux/arm64`, the Dockerfile builds `libpisp` and Raspberry Pi's `libcamera` fork, including the `libcamerasrc` GStreamer plugin. Ubuntu 22.04 does not distribute that plugin for arm64. The upstream references can be overridden with the `LIBPISP_REF` and `LIBCAMERA_REF` build arguments.
