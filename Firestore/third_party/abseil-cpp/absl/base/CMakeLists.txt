#
# Copyright 2017 The Abseil Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

list(APPEND BASE_PUBLIC_HEADERS
  "attributes.h"
  "config.h"
  "dynamic_annotations.h"
  "log_severity.h"
  "macros.h"
  "optimization.h"
  "policy_checks.h"
  "port.h"
)


list(APPEND BASE_INTERNAL_HEADERS
  "internal/atomic_hook.h"
  "internal/endian.h"
  "internal/identity.h"
  "internal/inline_variable.h"
  "internal/raw_logging.h"
  "internal/throw_delegate.h"
  "internal/unaligned_access.h"
)


# absl_base main library
list(APPEND BASE_SRC
  "internal/raw_logging.cc"
  ${BASE_PUBLIC_HEADERS}
  ${BASE_INTERNAL_HEADERS}
)

absl_library(
  TARGET
    absl_base
  SOURCES
    ${BASE_SRC}
  PUBLIC_LIBRARIES
    absl_dynamic_annotations
  EXPORT_NAME
    base
)


# throw delegate library
set(THROW_DELEGATE_SRC "internal/throw_delegate.cc")

absl_library(
  TARGET
    absl_throw_delegate
  SOURCES
    ${THROW_DELEGATE_SRC}
  PUBLIC_LIBRARIES
    ${THROW_DELEGATE_PUBLIC_LIBRARIES}
  PRIVATE_COMPILE_FLAGS
    ${ABSL_EXCEPTIONS_FLAG}
  EXPORT_NAME
    throw_delegate
)


# dynamic_annotations library
set(DYNAMIC_ANNOTATIONS_SRC "dynamic_annotations.cc")

absl_library(
  TARGET
    absl_dynamic_annotations
  SOURCES
    ${DYNAMIC_ANNOTATIONS_SRC}
)


#
## TESTS
#

# test inline_variable_test
list(APPEND INLINE_VARIABLE_TEST_SRC
  "internal/inline_variable_testing.h"
  "inline_variable_test.cc"
  "inline_variable_test_a.cc"
  "inline_variable_test_b.cc"
)

set(INLINE_VARIABLE_TEST_PUBLIC_LIBRARIES absl::base)

absl_test(
  TARGET
    inline_variable_test
  SOURCES
    ${INLINE_VARIABLE_TEST_SRC}
  PUBLIC_LIBRARIES
    ${INLINE_VARIABLE_TEST_PUBLIC_LIBRARIES}
)


# test endian_test
set(ENDIAN_TEST_SRC "internal/endian_test.cc")

absl_test(
  TARGET
    endian_test
  SOURCES
    ${ENDIAN_TEST_SRC}
)


# test config_test
set(CONFIG_TEST_SRC "config_test.cc")
set(CONFIG_TEST_PUBLIC_LIBRARIES absl::base)
absl_test(
  TARGET
    config_test
  SOURCES
    ${CONFIG_TEST_SRC}
  PUBLIC_LIBRARIES
    ${CONFIG_TEST_PUBLIC_LIBRARIES}
)


# test raw_logging_test
set(RAW_LOGGING_TEST_SRC "raw_logging_test.cc")
set(RAW_LOGGING_TEST_PUBLIC_LIBRARIES absl::base)

absl_test(
  TARGET
    raw_logging_test
  SOURCES
    ${RAW_LOGGING_TEST_SRC}
  PUBLIC_LIBRARIES
    ${RAW_LOGGING_TEST_PUBLIC_LIBRARIES}
)
