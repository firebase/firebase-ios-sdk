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
include(ExternalProjectFlags)

ExternalProject_GitSource(
  PROTOBUF_GIT
  GIT_REPOSITORY "https://github.com/google/protobuf.git"
  GIT_TAG "v3.5.1.1"
)

ExternalProject_Add(
  protobuf

  ${PROTOBUF_GIT}

  PREFIX ${PROJECT_BINARY_DIR}/external/protobuf

  UPDATE_COMMAND ""
  CONFIGURE_COMMAND cd <SOURCE_DIR> && ./autogen.sh
    COMMAND <SOURCE_DIR>/configure --prefix=${PREFIX}
  INSTALL_COMMAND ""
)
