# Copyright 2018 Google
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

include(ExternalProject)

if(TARGET firebase_cpp)
  return()
endif()

set(version 5.4.0)

ExternalProject_Add(
  firebase_cpp

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  URL https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_${version}.zip
  URL_HASH SHA256=e21302574a806ee6111e58eef9cf226ac61e2736bc98e7abee2b44fb41deaa6b

  PREFIX ${PROJECT_BINARY_DIR}

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
