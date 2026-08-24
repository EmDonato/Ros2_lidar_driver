# LD06 LiDAR ROS 2 driver

This repository contains a ROS 2 Humble serial driver for the LDROBOT LD06
2D LiDAR. The image builds the driver from source and starts it automatically.
It has no RealSense, libcamera, or custom interface dependency.

## Repository layout

- `src/lidar_driver`: ROS 2 package and executable.
- `config/params.yaml`: default runtime parameters.
- `Dockerfile`: single-stage source build.
- `compose.yaml`: Raspberry Pi 5 runtime example.

## Dependencies and device

The ROS package depends on `rclcpp` and `sensor_msgs`; serial communication
uses the Linux termios API and POSIX threads already provided by the base
system. It does not require RealSense, libcamera, or custom interface packages.

Runtime requires an LD06 serial device, `/dev/ttyUSB0` by default.

## Build and run

Run from this repository:

```bash
docker compose build
docker compose up
```

The default platform is `linux/arm64`. Build natively on an x86-64 development
machine with:

```bash
ROBOT_PLATFORM=linux/amd64 docker compose build
```

Set a different ROS domain when required:

```bash
ROS_DOMAIN_ID=7 docker compose up
```

The container runs as a non-root `ros` user and Compose exposes the host device
tree in privileged mode. The default serial device is `/dev/ttyUSB0`.

## Parameters

Defaults are stored in `config/params.yaml` and mounted read-only at runtime.

| Parameter | Default | Description |
| --- | --- | --- |
| `port` | `/dev/ttyUSB0` | LD06 serial device. |
| `frame_id` | `laser_link` | Frame assigned to published scans. |
| `publish_period_ms` | `100` | Scan publication period in milliseconds. |
| `masked_index_start` | `114` | First scan index hidden by the robot body. |
| `masked_index_end` | `122` | Last scan index hidden by the robot body. |

The mask represents the area where parts of the robot obstruct the LiDAR. Both
mask parameters can be set to `-1` to disable it. Values beyond the available
scan length are safely clamped or ignored.

## ROS interfaces

The node is named `/lidar_driver` and publishes:

- `scan` (`sensor_msgs/msg/LaserScan`) with Sensor Data QoS.

Ranges inside the configured mask are published as `NaN`. The default frame is
`laser_link`. The driver does not create ROS services.

## Troubleshooting

- Confirm that the sensor exists with `ls -l /dev/ttyUSB0`.
- Update `port` in `config/params.yaml` if the kernel assigns another path.
- Verify that the container user can access the device group when the driver
  reports that the serial port cannot be opened.
- The LD06 serial implementation uses its required 230400 baud configuration.
