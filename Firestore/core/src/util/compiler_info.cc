// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "Firestore/core/src/util/compiler_info.h"

#include <sstream>
#include <utility>

#include "Firestore/core/src/util/string_format.h"
#include "absl/base/config.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

// The code in this file is adapted from
// https://github.com/googleapis/google-cloud-cpp/blob/master/google/cloud/internal/compiler_info.cc and
// https://github.com/googleapis/google-cloud-cpp/blob/master/google/cloud/internal/port_platform.cc.

/**
 * Returns the compiler ID.
 *
 * The Compiler ID is a string like "GNU" or "Clang", as described by
 * https://cmake.org/cmake/help/v3.5/variable/CMAKE_LANG_COMPILER_ID.html
 */
std::string CompilerId() {
  // The macros for determining the compiler ID are taken from:
  // https://gitlab.kitware.com/cmake/cmake/tree/v3.5.0/Modules/Compiler/\*-DetermineCompiler.cmake
  // We do not care to detect every single compiler possible and only target the
  // most popular ones.
  //
  // Order is significant as some compilers can define the same macros.

#if defined(__apple_build_version__) && defined(__clang__)
  return "AppleClang";
#elif defined(__clang__)
  return "Clang";
#elif defined(__GNUC__)
  return "GNU";
#elif defined(_MSC_VER)
  return "MSVC";
#endif

  return "Unknown";
}

/** Returns the compiler version. This string will be something like "9.1.1". */
std::string CompilerVersion() {
  std::ostringstream os;

#if defined(__apple_build_version__) && defined(__clang__)
  os << __clang_major__ << "." << __clang_minor__ << "." << __clang_patchlevel__
     << "." << __apple_build_version__;

#elif defined(__clang__)
  os << __clang_major__ << "." << __clang_minor__ << "."
     << __clang_patchlevel__;

#elif defined(__GNUC__)
  os << __GNUC__ << "." << __GNUC_MINOR__ << "." << __GNUC_PATCHLEVEL__;

#elif defined(_MSC_VER)
  os << _MSC_VER / 100 << ".";
  os << _MSC_VER % 100;
#if defined(_MSC_FULL_VER)
#if _MSC_VER >= 1400
  os << "." << _MSC_FULL_VER % 100000;
#else
  os << "." << _MSC_FULL_VER % 10000;
#endif  // _MSC_VER >= 1400
#endif  // defined(_MSC_VER)

#else
  os << "Unknown";

#endif  // defined(__apple_build_version__) && defined(__clang__)

  return std::move(os).str();
}

/**
 * Returns certain interesting compiler features.
 *
 * Currently this returns one of "ex" or "noex" to indicate whether or not
 * C++ exceptions are enabled.
 */
std::string CompilerFeatures() {
#if ABSL_HAVE_EXCEPTIONS
  return "ex";
#else
  return "noex";
#endif  // ABSL_HAVE_EXCEPTIONS
}

// Microsoft Visual Studio does not define `__cplusplus` correctly by default:
// https://devblogs.microsoft.com/cppblog/msvc-now-correctly-reports-__cplusplus
// Instead, `_MSVC_LANG` macro can be used which uses the same version numbers
// as the standard `__cplusplus` macro (except when the `/std:c++latest` option
// is used, in which case it will be higher).
#ifdef _MSC_VER
#define FIRESTORE__CPLUSPLUS _MSVC_LANG
#else
#define FIRESTORE__CPLUSPLUS __cplusplus
#endif  // _MSC_VER

/** Returns the 4-digit year of the C++ language standard. */
std::string LanguageVersion() {
  switch (FIRESTORE__CPLUSPLUS) {
    case 199711L:
      return "1998";
    case 201103L:
      return "2011";
    case 201402L:
      return "2014";
    case 201703L:
      return "2017";
    case 202002L:
      return "2020";
    default:
#ifdef _MSC_VER
      // According to
      // https://docs.microsoft.com/en-us/cpp/preprocessor/predefined-macros,
      // _MSVC_LANG is "set to a higher, unspecified value when the
      // `/std:c++latest` option is specified".
      if (FIRESTORE__CPLUSPLUS > 202002L) {
        return "latest";
      }
#endif  // _MSC_VER
      return "unknown";
  }
}

std::string StandardLibraryVendor() {
#if defined(_STLPORT_VERSION)
  return "stlport";
#elif defined(__GLIBCXX__) || defined(__GLIBCPP__)
  return "gnustl";
#elif defined(_LIBCPP_STD_VER)
  return "libcpp";
#else
  return "unknown";
#endif
}

}  // namespace

std::string GetFullCompilerInfo() {
  return StringFormat("%s-%s-%s-%s-%s", CompilerId(), CompilerVersion(),
                      CompilerFeatures(), LanguageVersion(),
                      StandardLibraryVendor());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
