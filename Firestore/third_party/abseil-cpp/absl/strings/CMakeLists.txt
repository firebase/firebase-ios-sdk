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


list(APPEND STRINGS_PUBLIC_HEADERS
  "ascii.h"
  "match.h"
  "string_view.h"
)


list(APPEND STRINGS_INTERNAL_HEADERS
  "internal/memutil.h"
  "internal/resize_uninitialized.h"
)



# add string library
list(APPEND STRINGS_SRC
  "ascii.cc"
  "internal/memutil.cc"
  "match.cc"
  "string_view.cc"
  ${STRINGS_PUBLIC_HEADERS}
  ${STRINGS_INTERNAL_HEADERS}
)
set(STRINGS_PUBLIC_LIBRARIES absl::base absl_throw_delegate)

absl_library(
  TARGET
    absl_strings
  SOURCES
    ${STRINGS_SRC}
  PUBLIC_LIBRARIES
    ${STRINGS_PUBLIC_LIBRARIES}
  EXPORT_NAME
    strings
)


#
## TESTS
#

# test match_test
set(MATCH_TEST_SRC "match_test.cc")
set(MATCH_TEST_PUBLIC_LIBRARIES absl::strings)

absl_test(
  TARGET
    match_test
  SOURCES
    ${MATCH_TEST_SRC}
  PUBLIC_LIBRARIES
    ${MATCH_TEST_PUBLIC_LIBRARIES}
)


# test ascii_test
set(ASCII_TEST_SRC "ascii_test.cc")
set(ASCII_TEST_PUBLIC_LIBRARIES absl::strings)

absl_test(
  TARGET
    ascii_test
  SOURCES
    ${ASCII_TEST_SRC}
  PUBLIC_LIBRARIES
    ${ASCII_TEST_PUBLIC_LIBRARIES}
)


# test memutil_test
set(MEMUTIL_TEST_SRC "internal/memutil_test.cc")
set(MEMUTIL_TEST_PUBLIC_LIBRARIES absl::strings)

absl_test(
  TARGET
    memutil_test
  SOURCES
    ${MEMUTIL_TEST_SRC}
  PUBLIC_LIBRARIES
    ${MEMUTIL_TEST_PUBLIC_LIBRARIES}
)


# test string_view_test
set(STRING_VIEW_TEST_SRC "string_view_test.cc")
set(STRING_VIEW_TEST_PUBLIC_LIBRARIES absl::strings absl_throw_delegate absl::base)

absl_test(
  TARGET
    string_view_test
  SOURCES
    ${STRING_VIEW_TEST_SRC}
  PUBLIC_LIBRARIES
    ${STRING_VIEW_TEST_PUBLIC_LIBRARIES}
)


# test resize_uninitialized_test
set(RESIZE_UNINITIALIZED_TEST_SRC "internal/resize_uninitialized_test.cc")

absl_test(
  TARGET
    resize_uninitialized_test
  SOURCES
    ${RESIZE_UNINITIALIZED_TEST_SRC}
)
