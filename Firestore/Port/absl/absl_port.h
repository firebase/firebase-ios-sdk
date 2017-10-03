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

// Various portability macros, type definitions, and inline functions
// This file is used for both C and C++!
//
// These are weird things we need to do to get this compiling on
// random systems (and on SWIG).
//
// This files is structured into the following high-level categories:
// - Platform checks (OS, Compiler, C++, Library)
// - Feature macros
// - Utility macros
// - Utility functions
// - Type alias
// - Predefined system/language macros
// - Predefined system/language functions
// - Compiler attributes (__attribute__)
// - Performance optimization (alignment, branch prediction)
// - Obsolete
//

#ifndef THIRD_PARTY_ABSL_BASE_PORT_H_
#define THIRD_PARTY_ABSL_BASE_PORT_H_

#include <assert.h>
#include <limits.h>  // So we can set the bounds of our types
#include <stdlib.h>  // for free()
#include <string.h>  // for memcpy()

#include "absl_attributes.h"
#include "absl_config.h"
#include "absl_integral_types.h"

#ifdef SWIG
%include "attributes.h"
#endif

// -----------------------------------------------------------------------------
// Operating System Check
// -----------------------------------------------------------------------------

#if defined(__CYGWIN__)
#error "Cygwin is not supported."
#endif

// -----------------------------------------------------------------------------
// Compiler Check
// -----------------------------------------------------------------------------

// We support MSVC++ 14.0 update 2 and later.
#if defined(_MSC_FULL_VER) && _MSC_FULL_VER < 190023918
#error "This package requires Visual Studio 2015 Update 2 or higher"
#endif

// We support gcc 4.7 and later.
#if defined(__GNUC__) && !defined(__clang__)
#if __GNUC__ < 4 || (__GNUC__ == 4 && __GNUC_MINOR__ < 7)
#error "This package requires gcc 4.7 or higher"
#endif
#endif

// We support Apple Xcode clang 4.2.1 (version 421.11.65) and later.
// This corresponds to Apple Xcode version 4.5.
#if defined(__apple_build_version__) && __apple_build_version__ < 4211165
#error "This package requires __apple_build_version__ of 4211165 or higher"
#endif

// -----------------------------------------------------------------------------
// C++ Version Check
// -----------------------------------------------------------------------------

// Enforce C++11 as the minimum.  Note that Visual Studio has not
// advanced __cplusplus despite being good enough for our purposes, so
// so we exempt it from the check.
#if defined(__cplusplus) && !defined(_MSC_VER) && !defined(SWIG)
#if __cplusplus < 201103L
#error "C++ versions less than C++11 are not supported."
#endif
#endif

// -----------------------------------------------------------------------------
// C++ Standard Library Check
// -----------------------------------------------------------------------------

#if defined(__cplusplus)
#include <cstddef>
#if defined(_STLPORT_VERSION)
#error "STLPort is not supported."
#endif
#endif

// -----------------------------------------------------------------------------
// Feature Macros
// -----------------------------------------------------------------------------

// ABSL_HAVE_TLS is defined to 1 when __thread should be supported.
// We assume __thread is supported on Linux when compiled with Clang or compiled
// against libstdc++ with _GLIBCXX_HAVE_TLS defined.
#ifdef ABSL_HAVE_TLS
#error ABSL_HAVE_TLS cannot be directly set
#elif defined(__linux__) && (defined(__clang__) || defined(_GLIBCXX_HAVE_TLS))
#define ABSL_HAVE_TLS 1
#endif

// -----------------------------------------------------------------------------
// Utility Macros
// -----------------------------------------------------------------------------

// ABSL_FUNC_PTR_TO_CHAR_PTR
// On some platforms, a "function pointer" points to a function descriptor
// rather than directly to the function itself.
// Use ABSL_FUNC_PTR_TO_CHAR_PTR(func) to get a char-pointer to the first
// instruction of the function func.
#if defined(__cplusplus)
#if (defined(__powerpc__) && !(_CALL_ELF > 1)) || defined(__ia64)
// use opd section for function descriptors on these platforms, the function
// address is the first word of the descriptor
namespace absl {
enum { kPlatformUsesOPDSections = 1 };
}  // namespace absl
#define ABSL_FUNC_PTR_TO_CHAR_PTR(func) (reinterpret_cast<char **>(func)[0])
#else  // not PPC or IA64
namespace absl {
enum { kPlatformUsesOPDSections = 0 };
}  // namespace absl
#define ABSL_FUNC_PTR_TO_CHAR_PTR(func) (reinterpret_cast<char *>(func))
#endif  // PPC or IA64
#endif  // __cplusplus

// -----------------------------------------------------------------------------
// Utility Functions
// -----------------------------------------------------------------------------

#if defined(__cplusplus)
namespace absl {
constexpr char PathSeparator() {
#ifdef _WIN32
  return '\\';
#else
  return '/';
#endif
}
}  // namespace absl
#endif  // __cplusplus

// -----------------------------------------------------------------------------
// Type Alias
// -----------------------------------------------------------------------------

#ifdef _MSC_VER
// uid_t
// MSVC doesn't have uid_t
typedef int uid_t;

// pid_t
// Defined all over the place.
typedef int pid_t;

// ssize_t
// VC++ doesn't understand "ssize_t". SSIZE_T is defined in <basetsd.h>.
#include <basetsd.h>
typedef SSIZE_T ssize_t;
#endif  // _MSC_VER

// -----------------------------------------------------------------------------
// Predefined System/Language Macros
// -----------------------------------------------------------------------------

// MAP_ANONYMOUS
#if defined(__APPLE__) && defined(__MACH__)
// For mmap, Linux defines both MAP_ANONYMOUS and MAP_ANON and says MAP_ANON is
// deprecated. In Darwin, MAP_ANON is all there is.
#if !defined MAP_ANONYMOUS
#define MAP_ANONYMOUS MAP_ANON
#endif  // !MAP_ANONYMOUS
#endif  // __APPLE__ && __MACH__

// PATH_MAX
// You say tomato, I say atotom
#ifdef _MSC_VER
#define PATH_MAX MAX_PATH
#endif

// -----------------------------------------------------------------------------
// Performance Optimization
// -----------------------------------------------------------------------------

// Alignment

// CACHELINE_SIZE, CACHELINE_ALIGNED
// Deprecated: Use ABSL_CACHELINE_SIZE, ABSL_CACHELINE_ALIGNED.
// Note: When C++17 is available, consider using the following:
// - std::hardware_constructive_interference_size
// - std::hardware_destructive_interference_size
// See http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2016/p0154r1.html
#if defined(__GNUC__)
#if defined(__i386__) || defined(__x86_64__)
#define CACHELINE_SIZE 64
#define ABSL_CACHELINE_SIZE 64
#elif defined(__powerpc64__)
#define CACHELINE_SIZE 128
#define ABSL_CACHELINE_SIZE 128
#elif defined(__aarch64__)
// We would need to read special register ctr_el0 to find out L1 dcache size.
// This value is a good estimate based on a real aarch64 machine.
#define CACHELINE_SIZE 64
#define ABSL_CACHELINE_SIZE 64
#elif defined(__arm__)
// Cache line sizes for ARM: These values are not strictly correct since
// cache line sizes depend on implementations, not architectures.  There
// are even implementations with cache line sizes configurable at boot
// time.
#if defined(__ARM_ARCH_5T__)
#define CACHELINE_SIZE 32
#define ABSL_CACHELINE_SIZE 32
#elif defined(__ARM_ARCH_7A__)
#define CACHELINE_SIZE 64
#define ABSL_CACHELINE_SIZE 64
#endif
#endif

#ifndef CACHELINE_SIZE
// A reasonable default guess.  Note that overestimates tend to waste more
// space, while underestimates tend to waste more time.
#define CACHELINE_SIZE 64
#define ABSL_CACHELINE_SIZE 64
#endif

// On some compilers, expands to __attribute__((aligned(CACHELINE_SIZE))).
// For compilers where this is not known to work, expands to nothing.
//
// No further guarantees are made here.  The result of applying the macro
// to variables and types is always implementation defined.
//
// WARNING: It is easy to use this attribute incorrectly, even to the point
// of causing bugs that are difficult to diagnose, crash, etc.  It does not
// guarantee that objects are aligned to a cache line.
//
// Recommendations:
//
// 1) Consult compiler documentation; this comment is not kept in sync as
//    toolchains evolve.
// 2) Verify your use has the intended effect. This often requires inspecting
//    the generated machine code.
// 3) Prefer applying this attribute to individual variables.  Avoid
//    applying it to types.  This tends to localize the effect.
#define CACHELINE_ALIGNED __attribute__((aligned(CACHELINE_SIZE)))
#define ABSL_CACHELINE_ALIGNED __attribute__((aligned(ABSL_CACHELINE_SIZE)))

#else  // not GCC
#define CACHELINE_SIZE 64
#define ABSL_CACHELINE_SIZE 64
#define CACHELINE_ALIGNED
#define ABSL_CACHELINE_ALIGNED
#endif

// unaligned APIs

// Portable handling of unaligned loads, stores, and copies.
// On some platforms, like ARM, the copy functions can be more efficient
// then a load and a store.
//
// It is possible to implement all of these these using constant-length memcpy
// calls, which is portable and will usually be inlined into simple loads and
// stores if the architecture supports it. However, such inlining usually
// happens in a pass that's quite late in compilation, which means the resulting
// loads and stores cannot participate in many other optimizations, leading to
// overall worse code.

// The unaligned API is C++ only.  The declarations use C++ features
// (namespaces, inline) which are absent or incompatible in C.
#if defined(__cplusplus)

#if defined(ADDRESS_SANITIZER) || defined(THREAD_SANITIZER) || defined(MEMORY_SANITIZER)
// Consider we have an unaligned load/store of 4 bytes from address 0x...05.
// AddressSanitizer will treat it as a 3-byte access to the range 05:07 and
// will miss a bug if 08 is the first unaddressable byte.
// ThreadSanitizer will also treat this as a 3-byte access to 05:07 and will
// miss a race between this access and some other accesses to 08.
// MemorySanitizer will correctly propagate the shadow on unaligned stores
// and correctly report bugs on unaligned loads, but it may not properly
// update and report the origin of the uninitialized memory.
// For all three tools, replacing an unaligned access with a tool-specific
// callback solves the problem.

// Make sure uint16_t/uint32_t/uint64_t are defined.
#include <stdint.h>

extern "C" {
uint16_t __sanitizer_unaligned_load16(const void *p);
uint32_t __sanitizer_unaligned_load32(const void *p);
uint64_t __sanitizer_unaligned_load64(const void *p);
void __sanitizer_unaligned_store16(void *p, uint16_t v);
void __sanitizer_unaligned_store32(void *p, uint32_t v);
void __sanitizer_unaligned_store64(void *p, uint64_t v);
}  // extern "C"

inline uint16 UNALIGNED_LOAD16(const void *p) {
  return __sanitizer_unaligned_load16(p);
}

inline uint32 UNALIGNED_LOAD32(const void *p) {
  return __sanitizer_unaligned_load32(p);
}

inline uint64 UNALIGNED_LOAD64(const void *p) {
  return __sanitizer_unaligned_load64(p);
}

inline void UNALIGNED_STORE16(void *p, uint16 v) {
  __sanitizer_unaligned_store16(p, v);
}

inline void UNALIGNED_STORE32(void *p, uint32 v) {
  __sanitizer_unaligned_store32(p, v);
}

inline void UNALIGNED_STORE64(void *p, uint64 v) {
  __sanitizer_unaligned_store64(p, v);
}

#elif defined(__x86_64__) || defined(_M_X64) || defined(__i386) || defined(_M_IX86) || \
    defined(__ppc__) || defined(__PPC__) || defined(__ppc64__) || defined(__PPC64__)

// x86 and x86-64 can perform unaligned loads/stores directly;
// modern PowerPC hardware can also do unaligned integer loads and stores;
// but note: the FPU still sends unaligned loads and stores to a trap handler!

#define UNALIGNED_LOAD16(_p) (*reinterpret_cast<const uint16 *>(_p))
#define UNALIGNED_LOAD32(_p) (*reinterpret_cast<const uint32 *>(_p))
#define UNALIGNED_LOAD64(_p) (*reinterpret_cast<const uint64 *>(_p))

#define UNALIGNED_STORE16(_p, _val) (*reinterpret_cast<uint16 *>(_p) = (_val))
#define UNALIGNED_STORE32(_p, _val) (*reinterpret_cast<uint32 *>(_p) = (_val))
#define UNALIGNED_STORE64(_p, _val) (*reinterpret_cast<uint64 *>(_p) = (_val))

#elif defined(__arm__) && !defined(__ARM_ARCH_5__) && !defined(__ARM_ARCH_5T__) &&           \
    !defined(__ARM_ARCH_5TE__) && !defined(__ARM_ARCH_5TEJ__) && !defined(__ARM_ARCH_6__) && \
    !defined(__ARM_ARCH_6J__) && !defined(__ARM_ARCH_6K__) && !defined(__ARM_ARCH_6Z__) &&   \
    !defined(__ARM_ARCH_6ZK__) && !defined(__ARM_ARCH_6T2__)

// ARMv7 and newer support native unaligned accesses, but only of 16-bit
// and 32-bit values (not 64-bit); older versions either raise a fatal signal,
// do an unaligned read and rotate the words around a bit, or do the reads very
// slowly (trip through kernel mode). There's no simple #define that says just
// “ARMv7 or higher”, so we have to filter away all ARMv5 and ARMv6
// sub-architectures. Newer gcc (>= 4.6) set an __ARM_FEATURE_ALIGNED #define,
// so in time, maybe we can move on to that.
//
// This is a mess, but there's not much we can do about it.
//
// To further complicate matters, only LDR instructions (single reads) are
// allowed to be unaligned, not LDRD (two reads) or LDM (many reads). Unless we
// explicitly tell the compiler that these accesses can be unaligned, it can and
// will combine accesses. On armcc, the way to signal this is done by accessing
// through the type (uint32 __packed *), but GCC has no such attribute
// (it ignores __attribute__((packed)) on individual variables). However,
// we can tell it that a _struct_ is unaligned, which has the same effect,
// so we do that.

namespace base {
namespace internal {

struct Unaligned16Struct {
  uint16 value;
  uint8 dummy;  // To make the size non-power-of-two.
} ATTRIBUTE_PACKED;

struct Unaligned32Struct {
  uint32 value;
  uint8 dummy;  // To make the size non-power-of-two.
} ATTRIBUTE_PACKED;

}  // namespace internal
}  // namespace base

#define UNALIGNED_LOAD16(_p) \
  ((reinterpret_cast<const ::base::internal::Unaligned16Struct *>(_p))->value)
#define UNALIGNED_LOAD32(_p) \
  ((reinterpret_cast<const ::base::internal::Unaligned32Struct *>(_p))->value)

#define UNALIGNED_STORE16(_p, _val) \
  ((reinterpret_cast< ::base::internal::Unaligned16Struct *>(_p))->value = (_val))
#define UNALIGNED_STORE32(_p, _val) \
  ((reinterpret_cast< ::base::internal::Unaligned32Struct *>(_p))->value = (_val))

inline uint64 UNALIGNED_LOAD64(const void *p) {
  uint64 t;
  memcpy(&t, p, sizeof t);
  return t;
}

inline void UNALIGNED_STORE64(void *p, uint64 v) {
  memcpy(p, &v, sizeof v);
}

#else

#define NEED_ALIGNED_LOADS

// These functions are provided for architectures that don't support
// unaligned loads and stores.

inline uint16 UNALIGNED_LOAD16(const void *p) {
  uint16 t;
  memcpy(&t, p, sizeof t);
  return t;
}

inline uint32 UNALIGNED_LOAD32(const void *p) {
  uint32 t;
  memcpy(&t, p, sizeof t);
  return t;
}

inline uint64 UNALIGNED_LOAD64(const void *p) {
  uint64 t;
  memcpy(&t, p, sizeof t);
  return t;
}

inline void UNALIGNED_STORE16(void *p, uint16 v) {
  memcpy(p, &v, sizeof v);
}

inline void UNALIGNED_STORE32(void *p, uint32 v) {
  memcpy(p, &v, sizeof v);
}

inline void UNALIGNED_STORE64(void *p, uint64 v) {
  memcpy(p, &v, sizeof v);
}

#endif

// The UNALIGNED_LOADW and UNALIGNED_STOREW macros load and store values
// of type uword_t.
#ifdef _LP64
#define UNALIGNED_LOADW(_p) UNALIGNED_LOAD64(_p)
#define UNALIGNED_STOREW(_p, _val) UNALIGNED_STORE64(_p, _val)
#else
#define UNALIGNED_LOADW(_p) UNALIGNED_LOAD32(_p)
#define UNALIGNED_STOREW(_p, _val) UNALIGNED_STORE32(_p, _val)
#endif

inline void UnalignedCopy16(const void *src, void *dst) {
  UNALIGNED_STORE16(dst, UNALIGNED_LOAD16(src));
}

inline void UnalignedCopy32(const void *src, void *dst) {
  UNALIGNED_STORE32(dst, UNALIGNED_LOAD32(src));
}

inline void UnalignedCopy64(const void *src, void *dst) {
  if (sizeof(void *) == 8) {
    UNALIGNED_STORE64(dst, UNALIGNED_LOAD64(src));
  } else {
    const char *src_char = reinterpret_cast<const char *>(src);
    char *dst_char = reinterpret_cast<char *>(dst);

    UNALIGNED_STORE32(dst_char, UNALIGNED_LOAD32(src_char));
    UNALIGNED_STORE32(dst_char + 4, UNALIGNED_LOAD32(src_char + 4));
  }
}

#endif  // defined(__cplusplus), end of unaligned API

// PREDICT_TRUE, PREDICT_FALSE
//
// GCC can be told that a certain branch is not likely to be taken (for
// instance, a CHECK failure), and use that information in static analysis.
// Giving it this information can help it optimize for the common case in
// the absence of better information (ie. -fprofile-arcs).
#if ABSL_HAVE_BUILTIN(__builtin_expect) || (defined(__GNUC__) && !defined(__clang__))
#define PREDICT_FALSE(x) (__builtin_expect(x, 0))
#define PREDICT_TRUE(x) (__builtin_expect(!!(x), 1))
#define ABSL_PREDICT_FALSE(x) (__builtin_expect(x, 0))
#define ABSL_PREDICT_TRUE(x) (__builtin_expect(!!(x), 1))
#else
#define PREDICT_FALSE(x) x
#define PREDICT_TRUE(x) x
#define ABSL_PREDICT_FALSE(x) x
#define ABSL_PREDICT_TRUE(x) x
#endif

// ABSL_ASSERT
//
// In C++11, `assert` can't be used portably within constexpr functions.
// ABSL_ASSERT functions as a runtime assert but works in C++11 constexpr
// functions.  Example:
//
// constexpr double Divide(double a, double b) {
//   return ABSL_ASSERT(b != 0), a / b;
// }
//
// This macro is inspired by
// https://akrzemi1.wordpress.com/2017/05/18/asserts-in-constexpr-functions/
#if defined(NDEBUG)
#define ABSL_ASSERT(expr) (false ? (void)(expr) : (void)0)
#else
#define ABSL_ASSERT(expr) \
  (PREDICT_TRUE((expr)) ? (void)0 : [] { assert(false && #expr); }())  // NOLINT
#endif

// -----------------------------------------------------------------------------
// Obsolete (to be removed)
// -----------------------------------------------------------------------------

// HAS_GLOBAL_STRING
// Some platforms have a std::string class that is different from ::std::string
// (although the interface is the same, of course).  On other platforms,
// std::string is the same as ::std::string.
#if defined(__cplusplus) && !defined(SWIG)
#include <string>
#ifndef HAS_GLOBAL_STRING
using std::basic_string;
using std::string;
#endif  // HAS_GLOBAL_STRING
#endif  // SWIG, __cplusplus

#endif  // THIRD_PARTY_ABSL_BASE_PORT_H_
