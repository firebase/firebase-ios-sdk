#
# Copyright 2017 The Abseil Authors.
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
#

list(APPEND TYPES_PUBLIC_HEADERS
  "bad_optional_access.h"
  "optional.h"
)

# optional library
list(APPEND OPTIONAL_SRC
  "optional.cc"
)

absl_library(
  TARGET
    absl_optional
  SOURCES
    ${OPTIONAL_SRC}
  PUBLIC_LIBRARIES
    absl::base
  EXPORT_NAME
    optional
)


set(BAD_OPTIONAL_ACCESS_SRC "bad_optional_access.cc")
set(BAD_OPTIONAL_ACCESS_LIBRARIES absl::base)

absl_library(
  TARGET
    absl_bad_optional_access
  SOURCES
    ${BAD_OPTIONAL_ACCESS_SRC}
  PUBLIC_LIBRARIES
    ${BAD_OPTIONAL_ACCESS_PUBLIC_LIBRARIES}
  EXPORT_NAME
    bad_optional_access
)


#
## TESTS
#

# test optional_test
set(OPTIONAL_TEST_SRC "optional_test.cc")
set(OPTIONAL_TEST_PUBLIC_LIBRARIES absl::base absl::throw_delegate absl::optional absl_bad_optional_access)

absl_test(
  TARGET
    optional_test
  SOURCES
    ${OPTIONAL_TEST_SRC}
  PUBLIC_LIBRARIES
    ${OPTIONAL_TEST_PUBLIC_LIBRARIES}
)


