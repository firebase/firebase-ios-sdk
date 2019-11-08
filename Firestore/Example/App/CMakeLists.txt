# Copyright 2019 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

add_executable(macOS_Example_App MACOSX_BUNDLE
  macOS/main.m
  macOS/AppDelegate.m
  macOS/AppDelegate.h
)

add_objc_flags(macOS_Example_App
  macOS/main.m
  macOS/AppDelegate.m
  macOS/AppDelegate.h
)

target_link_libraries(macOS_Example_App PRIVATE "-framework AppKit")

set_target_properties(macOS_Example_App PROPERTIES
  MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/macOS/Info.plist
  )
