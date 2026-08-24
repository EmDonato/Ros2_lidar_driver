cmake_minimum_required(VERSION 3.10)
project(lidar_driver)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(sensor_msgs REQUIRED)

add_executable(lidar_driver
  src/cmd_interface_linux.cpp
  src/lipkg.cpp
  src/main.cpp
  src/tofbf.cpp
)

target_include_directories(lidar_driver
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/lidar_driver>
    $<INSTALL_INTERFACE:include>
)

ament_target_dependencies(lidar_driver
  rclcpp
  sensor_msgs
)

install(TARGETS lidar_driver
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY include/
  DESTINATION include
)

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
