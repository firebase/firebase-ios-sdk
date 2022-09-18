# Copyright 2017 Google
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

# Provide a mechanism for firebase-cpp-sdk to avoid unnecessarily building
# the Objective-C APIs and Tests, which it doesn't use.
option(FIRESTORE_INCLUDE_OBJC "Build the Firestore Objective-C layer" ON)

add_subdirectory(Protos)
add_subdirectory(Source)
add_subdirectory(core)
add_subdirectory(fuzzing)

add_subdirectory(Example)
