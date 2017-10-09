/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Defines preprocessor macros describing the presence of "features" available.
// This facilitates writing portable code by parameterizing the compilation
// based on the presence or lack of a feature.
//
// We define a feature as some interface we wish to program to: for example,
// some library function or system call.
//
// For example, suppose a programmer wants to write a program that uses the
// 'mmap' system call. Then one might write:
//
// #include "absl/base/config.h"
//
// #ifdef ABSL_HAVE_MMAP
// #include "sys/mman.h"
// #endif  //ABSL_HAVE_MMAP
//
// ...
// #ifdef ABSL_HAVE_MMAP
// void *ptr = mmap(...);
// ...
// #endif  // ABSL_HAVE_MMAP
//
// As a special note, using feature macros from config.h to determine whether
// to include a particular header requires violating the style guide's required
// ordering for headers: this is permitted.

#ifndef THIRD_PARTY_ABSL_BASE_CONFIG_H_
#define THIRD_PARTY_ABSL_BASE_CONFIG_H_

// Included for the __GLIBC__ macro (or similar macros on other systems).
#include <limits.h>

#ifdef __cplusplus
// Included for __GLIBCXX__, _LIBCPP_VERSION
#include <cstddef>
#endif  // __cplusplus

// If we're using glibc, make sure we meet a minimum version requirement
// before we proceed much further.
//
// We have chosen glibc 2.12 as the minimum as it was tagged for release
// in May, 2010 and includes some functionality used in Google software
// (for instance pthread_setname_np):
// https://sourceware.org/ml/libc-alpha/2010-05/msg00000.html
#ifdef __GLIBC_PREREQ
#if !__GLIBC_PREREQ(2, 12)
#error "Minimum required version of glibc is 2.12."
#endif
#endif

// ABSL_HAVE_BUILTIN is a function-like feature checking macro.
// It's a wrapper around __has_builtin, which is defined by only clang now.
// It evaluates to 1 if the builtin is supported or 0 if not.
// Define it to avoid an extra level of #ifdef __has_builtin check.
// http://releases.llvm.org/3.3/tools/clang/docs/LanguageExtensions.html
#ifdef __has_builtin
#define ABSL_HAVE_BUILTIN(x) __has_builtin(x)
#else
#define ABSL_HAVE_BUILTIN(x) 0
#endif

// ABSL_HAVE_STD_IS_TRIVIALLY_DESTRUCTIBLE is defined when
// std::is_trivially_destructible<T> is supported.
//
// All supported compilers using libc++ have it, as does gcc >= 4.8
// using libstdc++, as does Visual Studio.
// https://gcc.gnu.org/onlinedocs/gcc-4.8.1/libstdc++/manual/manual/status.html#status.iso.2011
// is the first version where std::is_trivially_destructible no longer
// appeared as missing in the Type properties row.
#ifdef ABSL_HAVE_STD_IS_TRIVIALLY_DESTRUCTIBLE
#error ABSL_HAVE_STD_IS_TRIVIALLY_DESTRUCTIBLE cannot be directly set
#elif defined(_LIBCPP_VERSION) ||                                        \
    (!defined(__clang__) && defined(__GNUC__) && defined(__GLIBCXX__) && \
     (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 8))) ||        \
    defined(_MSC_VER)
#define ABSL_HAVE_STD_IS_TRIVIALLY_DESTRUCTIBLE 1
#endif

// ABSL_HAVE_STD_IS_TRIVIALLY_CONSTRUCTIBLE is defined when
// std::is_trivially_default_constructible<T> and
// std::is_trivially_copy_constructible<T> are supported.
//
// ABSL_HAVE_STD_IS_TRIVIALLY_ASSIGNABLE is defined when
// std::is_trivially_copy_assignable<T> is supported.
//
// Clang with libc++ supports it, as does gcc >= 5.1 with either
// libc++ or libstdc++, as does Visual Studio.
// https://gcc.gnu.org/gcc-5/changes.html lists as new
// "std::is_trivially_constructible, std::is_trivially_assignable
// etc."
#if defined(ABSL_HAVE_STD_IS_TRIVIALLY_CONSTRUCTIBLE)
#error ABSL_HAVE_STD_IS_TRIVIALLY_CONSTRUCTIBLE cannot be directly set
#elif defined(ABSL_HAVE_STD_IS_TRIVIALLY_ASSIGNABLE)
#error ABSL_HAVE_STD_IS_TRIVIALLY_ASSIGNABLE cannot directly set
#elif (defined(__clang__) && defined(_LIBCPP_VERSION)) ||        \
    (!defined(__clang__) && defined(__GNUC__) &&                 \
     (__GNUC__ > 5 || (__GNUC__ == 5 && __GNUC_MINOR__ >= 1)) && \
     (defined(_LIBCPP_VERSION) || defined(__GLIBCXX__))) ||      \
    defined(_MSC_VER)
#define ABSL_HAVE_STD_IS_TRIVIALLY_CONSTRUCTIBLE 1
#define ABSL_HAVE_STD_IS_TRIVIALLY_ASSIGNABLE 1
#endif

// ABSL_HAVE_THREAD_LOCAL is defined when C++11's thread_local is available.
// Clang implements thread_local keyword but Xcode did not support the
// implementation until Xcode 8.
#ifdef ABSL_HAVE_THREAD_LOCAL
#error ABSL_HAVE_THREAD_LOCAL cannot be directly set
#elif !defined(__apple_build_version__) || __apple_build_version__ >= 8000042
#define ABSL_HAVE_THREAD_LOCAL 1
#endif

// ABSL_HAVE_INTRINSIC_INT128 is defined when the implementation provides the
// 128 bit integral type: __int128.
//
// __SIZEOF_INT128__ is defined by Clang and GCC when __int128 is supported.
// Clang on ppc64 and aarch64 are exceptions where __int128 exists but has a
// sporadic compiler crashing bug. Nvidia's nvcc also defines __GNUC__ and
// __SIZEOF_INT128__ but not all versions that do this support __int128. Support
// has been tested for versions >= 7.
#ifdef ABSL_HAVE_INTRINSIC_INT128
#error ABSL_HAVE_INTRINSIC_INT128 cannot be directly set
#elif (defined(__clang__) && defined(__SIZEOF_INT128__) && !defined(__ppc64__) &&     \
       !defined(__aarch64__)) ||                                                      \
    (defined(__CUDACC__) && defined(__SIZEOF_INT128__) && __CUDACC_VER__ >= 70000) || \
    (!defined(__clang__) && !defined(__CUDACC__) && defined(__GNUC__) &&              \
     defined(__SIZEOF_INT128__))
#define ABSL_HAVE_INTRINSIC_INT128 1
#endif

// Operating system-specific features.
//
// Currently supported operating systems and associated preprocessor
// symbols:
//
//   Linux and Linux-derived           __linux__
//   Android                           __ANDROID__ (implies __linux__)
//   Linux (non-Android)               __linux__ && !__ANDROID__
//   Darwin (Mac OS X and iOS)         __APPLE__ && __MACH__
//   Akaros (http://akaros.org)        __ros__
//   Windows                           _WIN32
//   NaCL                              __native_client__
//   AsmJS                             __asmjs__
//   Fuschia                           __Fuchsia__
//
// Note that since Android defines both __ANDROID__ and __linux__, one
// may probe for either Linux or Android by simply testing for __linux__.
//

// ABSL_HAVE_MMAP is defined when the system has an mmap(2) implementation
// as defined in POSIX.1-2001.
#ifdef ABSL_HAVE_MMAP
#error ABSL_HAVE_MMAP cannot be directly set
#elif defined(__linux__) || (defined(__APPLE__) && defined(__MACH__)) || defined(__ros__) || \
    defined(__native_client__) || defined(__asmjs__) || defined(__Fuchsia__)
#define ABSL_HAVE_MMAP 1
#endif

// ABSL_HAS_PTHREAD_GETSCHEDPARAM is defined when the system implements the
// pthread_(get|set)schedparam(3) functions as defined in POSIX.1-2001.
#ifdef ABSL_HAVE_PTHREAD_GETSCHEDPARAM
#error ABSL_HAVE_PTHREAD_GETSCHEDPARAM cannot be directly set
#elif defined(__linux__) || (defined(__APPLE__) && defined(__MACH__)) || defined(__ros__)
#define ABSL_HAVE_PTHREAD_GETSCHEDPARAM 1
#endif

// ABSL_HAVE_SCHED_YIELD is defined when the system implements
// sched_yield(2) as defined in POSIX.1-2001.
#ifdef ABSL_HAVE_SCHED_YIELD
#error ABSL_HAVE_SCHED_YIELD cannot be directly set
#elif defined(__linux__) || defined(__ros__) || defined(__native_client__)
#define ABSL_HAVE_SCHED_YIELD 1
#endif

// ABSL_HAVE_SEMAPHORE_H is defined when the system supports the <semaphore.h>
// header and sem_open(3) family of functions as standardized in POSIX.1-2001.
//
// Note: While Apple does have <semaphore.h> for both iOS and macOS, it is
// explicity deprecated and will cause build failures if enabled for those
// systems.  We side-step the issue by not defining it here for Apple platforms.
#ifdef ABSL_HAVE_SEMAPHORE_H
#error ABSL_HAVE_SEMAPHORE_H cannot be directly set
#elif defined(__linux__) || defined(__ros__)
#define ABSL_HAVE_SEMAPHORE_H 1
#endif

// Library-specific features.
#ifdef ABSL_HAVE_ALARM
#error ABSL_HAVE_ALARM cannot be directly set
#elif defined(__GOOGLE_GRTE_VERSION__)
// feature tests for Google's GRTE
#define ABSL_HAVE_ALARM 1
#elif defined(__GLIBC__)
// feature test for glibc
#define ABSL_HAVE_ALARM 1
#elif defined(_MSC_VER)
// feature tests for Microsoft's library
#elif defined(__native_client__)
#else
// other standard libraries
#define ABSL_HAVE_ALARM 1
#endif

#if defined(_STLPORT_VERSION)
#error "STLPort is not supported."
#endif

// -----------------------------------------------------------------------------
// Endianness
// -----------------------------------------------------------------------------
// Define ABSL_IS_LITTLE_ENDIAN, ABSL_IS_BIG_ENDIAN.
// Some compilers or system headers provide macros to specify endianness.
// Unfortunately, there is no standard for the names of the macros or even of
// the header files.
// Reference: https://sourceforge.net/p/predef/wiki/Endianness/
#if defined(ABSL_IS_BIG_ENDIAN) || defined(ABSL_IS_LITTLE_ENDIAN)
#error "ABSL_IS_(BIG|LITTLE)_ENDIAN cannot be directly set."

#elif defined(__GLIBC__) || defined(__linux__)
// Operating systems that use the GNU C library generally provide <endian.h>
// containing __BYTE_ORDER, __LITTLE_ENDIAN, __BIG_ENDIAN.
#include <endian.h>

#if __BYTE_ORDER == __LITTLE_ENDIAN
#define ABSL_IS_LITTLE_ENDIAN 1
#elif __BYTE_ORDER == __BIG_ENDIAN
#define ABSL_IS_BIG_ENDIAN 1
#else  // __BYTE_ORDER != __LITTLE_ENDIAN && __BYTE_ORDER != __BIG_ENDIAN
#error "Unknown endianness"
#endif  // __BYTE_ORDER

#elif defined(__APPLE__) && defined(__MACH__)
// Apple has <machine/endian.h> containing BYTE_ORDER, BIG_ENDIAN,
// LITTLE_ENDIAN.
#include <machine/endian.h>  // NOLINT(build/include)

#if BYTE_ORDER == LITTLE_ENDIAN
#define ABSL_IS_LITTLE_ENDIAN 1
#elif BYTE_ORDER == BIG_ENDIAN
#define ABSL_IS_BIG_ENDIAN 1
#else  // BYTE_ORDER != LITTLE_ENDIAN && BYTE_ORDER != BIG_ENDIAN
#error "Unknown endianness"
#endif  // BYTE_ORDER

#elif defined(_WIN32)
// Assume Windows is little-endian.
#define ABSL_IS_LITTLE_ENDIAN 1

#elif defined(__LITTLE_ENDIAN__) || defined(__ARMEL__) || defined(__THUMBEL__) || \
    defined(__AARCH64EL__) || defined(_MIPSEL) || defined(__MIPSEL) || defined(__MIPSEL__)
#define ABSL_IS_LITTLE_ENDIAN 1

#elif defined(__BIG_ENDIAN__) || defined(__ARMEB__) || defined(__THUMBEB__) || \
    defined(__AARCH64EB__) || defined(_MIPSEB) || defined(__MIPSEB) || defined(__MIPSEB__)
#define ABSL_IS_BIG_ENDIAN 1

#else
#error "absl endian detection needs to be set up on your platform."
#endif

// ABSL_HAVE_EXCEPTIONS is defined when exceptions are enabled.  Many
// compilers support a "no exceptions" mode that disables exceptions.
//
// Generally, when ABSL_HAVE_EXCEPTIONS is not defined:
//
// - Code using `throw` and `try` may not compile.
// - The `noexcept` specifier will still compile and behave as normal.
// - The `noexcept` operator may still return `false`.
//
// For further details, consult the compiler's documentation.
#ifdef ABSL_HAVE_EXCEPTIONS
#error ABSL_HAVE_EXCEPTIONS cannot be directly set.

#elif defined(__clang__)
// TODO
//   Switch to using __cpp_exceptions when we no longer support versions < 3.6.
// For details on this check, see:
//   https://goo.gl/PilDrJ
#if defined(__EXCEPTIONS) && __has_feature(cxx_exceptions)
#define ABSL_HAVE_EXCEPTIONS 1
#endif  // defined(__EXCEPTIONS) && __has_feature(cxx_exceptions)

// Handle remaining special cases and default to exceptions being supported.
#elif !(defined(__GNUC__) && (__GNUC__ < 5) && !defined(__EXCEPTIONS)) &&    \
    !(defined(__GNUC__) && (__GNUC__ >= 5) && !defined(__cpp_exceptions)) && \
    !(defined(_MSC_VER) && !defined(_CPPUNWIND))
#define ABSL_HAVE_EXCEPTIONS 1
#endif

#endif  // THIRD_PARTY_ABSL_BASE_CONFIG_H_
