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

add_subdirectory(include/firebase/firestore)

add_subdirectory(src/firebase/firestore)
add_subdirectory(src/firebase/firestore/auth)
add_subdirectory(src/firebase/firestore/core)
add_subdirectory(src/firebase/firestore/fuzzing)
add_subdirectory(src/firebase/firestore/immutable)
add_subdirectory(src/firebase/firestore/local)
add_subdirectory(src/firebase/firestore/model)
add_subdirectory(src/firebase/firestore/nanopb)
add_subdirectory(src/firebase/firestore/remote)
add_subdirectory(src/firebase/firestore/util)

add_subdirectory(test/firebase/firestore/testutil)
add_subdirectory(test/firebase/firestore)
add_subdirectory(test/firebase/firestore/auth)
add_subdirectory(test/firebase/firestore/core)
add_subdirectory(test/firebase/firestore/immutable)
add_subdirectory(test/firebase/firestore/local)
add_subdirectory(test/firebase/firestore/model)
add_subdirectory(test/firebase/firestore/remote)
add_subdirectory(test/firebase/firestore/util)
