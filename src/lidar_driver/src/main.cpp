#include "cmd_interface_linux.h"
#include "lipkg.h"
#include "rclcpp/rclcpp.hpp"
#include "sensor_msgs/msg/laser_scan.hpp"

#include <algorithm>
#include <chrono>
#include <limits>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>

class LidarDriver : public rclcpp::Node
{
public:
  LidarDriver()
  : Node("lidar_driver")
  {
    port_ = this->declare_parameter<std::string>("port", "/dev/ttyUSB0");
    frame_id_ = this->declare_parameter<std::string>("frame_id", "laser_link");
    publish_period_ms_ = this->declare_parameter<int>("publish_period_ms", 100);
    masked_index_start_ = this->declare_parameter<int>("masked_index_start", 114);
    masked_index_end_ = this->declare_parameter<int>("masked_index_end", 122);

    validate_parameters_();
    lidar_ = std::make_unique<LiPkg>(frame_id_);

    serial_port_.SetReadCallback(
      [this](const char * data, size_t length) {
        std::lock_guard<std::mutex> lock(lidar_mutex_);
        if (lidar_->Parse(reinterpret_cast<const uint8_t *>(data), length)) {
          lidar_->AssemblePacket();
        }
      });

    if (!serial_port_.Open(port_)) {
      throw std::runtime_error("Unable to open LiDAR serial port " + port_);
    }

    scan_pub_ = this->create_publisher<sensor_msgs::msg::LaserScan>(
      "scan", rclcpp::SensorDataQoS());
    timer_ = this->create_wall_timer(
      std::chrono::milliseconds(publish_period_ms_),
      std::bind(&LidarDriver::publish_scan_, this));

    RCLCPP_INFO(
      this->get_logger(),
      "LD06 driver started on %s with frame %s and a %d ms publish period",
      port_.c_str(), frame_id_.c_str(), publish_period_ms_);
  }

  ~LidarDriver() override
  {
    serial_port_.Close();
    RCLCPP_INFO(this->get_logger(), "LD06 serial port closed");
  }

private:
  std::string port_;
  std::string frame_id_;
  int publish_period_ms_{100};
  int masked_index_start_{114};
  int masked_index_end_{122};

  CmdInterfaceLinux serial_port_;
  std::unique_ptr<LiPkg> lidar_;
  std::mutex lidar_mutex_;
  rclcpp::Publisher<sensor_msgs::msg::LaserScan>::SharedPtr scan_pub_;
  rclcpp::TimerBase::SharedPtr timer_;

  void validate_parameters_() const
  {
    if (publish_period_ms_ <= 0) {
      throw std::invalid_argument("publish_period_ms must be greater than zero");
    }

    const bool mask_disabled = masked_index_start_ == -1 && masked_index_end_ == -1;
    const bool mask_valid =
      masked_index_start_ >= 0 && masked_index_end_ >= masked_index_start_;
    if (!mask_disabled && !mask_valid) {
      throw std::invalid_argument(
              "masked_index_start and masked_index_end must both be -1, or define a valid range");
    }
  }

  void publish_scan_()
  {
    std::lock_guard<std::mutex> lock(lidar_mutex_);
    if (!lidar_->IsFrameReady()) {
      return;
    }

    const auto scan = lidar_->GetLaserScan();
    lidar_->ResetFrameReady();
    if (scan.ranges.empty()) {
      return;
    }

    sensor_msgs::msg::LaserScan message;
    message.header.stamp = this->now();
    message.header.frame_id = frame_id_;
    message.angle_min = scan.angle_min;
    message.angle_max = scan.angle_max;
    message.angle_increment = scan.angle_increment;
    message.range_min = scan.range_min;
    message.range_max = scan.range_max;
    message.time_increment = scan.time_increment;
    message.scan_time = scan.scan_time;
    message.ranges.assign(scan.ranges.begin(), scan.ranges.end());
    message.intensities.assign(scan.intensities.begin(), scan.intensities.end());

    if (masked_index_start_ >= 0) {
      const size_t start = static_cast<size_t>(masked_index_start_);
      if (start < message.ranges.size()) {
        const size_t end = std::min(
          static_cast<size_t>(masked_index_end_), message.ranges.size() - 1);
        for (size_t index = start; index <= end; ++index) {
          message.ranges[index] = std::numeric_limits<float>::quiet_NaN();
        }
      }
    }

    scan_pub_->publish(message);
  }
};

int main(int argc, char ** argv)
{
  rclcpp::init(argc, argv);
  try {
    rclcpp::spin(std::make_shared<LidarDriver>());
  } catch (const std::exception & error) {
    if (rclcpp::ok()) {
      RCLCPP_FATAL(rclcpp::get_logger("lidar_driver"), "Driver startup failed: %s", error.what());
    }
    rclcpp::shutdown();
    return 1;
  }
  rclcpp::shutdown();
  return 0;
}
