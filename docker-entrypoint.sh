#!/usr/bin/env bash
set -e

source "/opt/ros/${ROS_DISTRO}/setup.bash"
source "${MODULE_SETUP:-/opt/robot_module/setup.bash}"
exec "$@"
