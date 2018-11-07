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

# Workaround to make the headers show up in IDEs
# (see https://stackoverflow.com/questions/27039019/ and open issue on CMake
# issue tracker: https://gitlab.kitware.com/cmake/cmake/issues/15234)
add_custom_target(firebase_firestore_types_ide SOURCES
    firestore_errors.h
    geo_point.h
    timestamp.h
)
