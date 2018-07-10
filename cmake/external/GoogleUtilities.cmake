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

include(xcodebuild)

if(TARGET GoogleUtilities)
  return()
endif()

if(APPLE)
  # GoogleUtilities is only available as a CocoaPod build.
  xcodebuild(GoogleUtilities)
else()
  # On non-Apple platforms, there's no way to build GoogleUtilities.
  add_custom_target(GoogleUtilities)
endif()
