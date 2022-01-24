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

#include "Firestore/core/src/util/ordered_code.h"

#include <cstddef>
#include <cstdint>
#include <limits>

#include "Firestore/core/src/util/bits.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "absl/base/casts.h"
#include "absl/base/internal/endian.h"
#include "absl/base/internal/unaligned_access.h"
#include "absl/base/port.h"
#include "absl/strings/internal/resize_uninitialized.h"

#if !defined(ABSL_IS_LITTLE_ENDIAN) && !defined(ABSL_IS_BIG_ENDIAN)
#error \
    "Unsupported byte order: Either ABSL_IS_BIG_ENDIAN or " \
       "ABSL_IS_LITTLE_ENDIAN must be defined"
#endif

#define UNALIGNED_LOAD16 ABSL_INTERNAL_UNALIGNED_LOAD16
#define UNALIGNED_LOAD32 ABSL_INTERNAL_UNALIGNED_LOAD32
#define UNALIGNED_LOAD64 ABSL_INTERNAL_UNALIGNED_LOAD64
#define UNALIGNED_STORE16 ABSL_INTERNAL_UNALIGNED_STORE16
#define UNALIGNED_STORE32 ABSL_INTERNAL_UNALIGNED_STORE32
#define UNALIGNED_STORE64 ABSL_INTERNAL_UNALIGNED_STORE64

// We encode a string in different ways depending on whether the item
// should be in lexicographically increasing or decreasing order.
//
//
// Lexicographically increasing order
//
// We want a string-to-string mapping F(x) such that for any two strings
//
//      x < y   =>   F(x) < F(y)
//
// In addition to the normal characters '\x00' through '\xff', we want to
// encode a few extra symbols in strings:
//
//      <sep>           Separator between items
//      <infinity>      Infinite string
//
// Therefore we need an alphabet with at least 258 symbols.  Each
// character '\1' through '\xfe' is mapped to itself.  The other four are
// encoded into two-letter sequences starting with '\0' and '\xff':
//
//      <sep>           encoded as =>           \0\1
//      \0              encoded as =>           \0\xff
//      \xff            encoded as =>           \xff\x00
//      <infinity>      encoded as =>           \xff\xff
//
// The remaining two-letter sequences starting with '\0' and '\xff' are
// currently unused.
//
// F(<infinity>) is defined above.  For any finite string x, F(x) is the
// the encodings of x's characters followed by the encoding for <sep>.  The
// ordering of two finite strings is the same as the ordering of the
// respective characters at the first position where they differ, which in
// turn is the same as the ordering of the encodings of those two
// characters.  Moreover, for every finite string x, F(x) < F(<infinity>).
//
//
// Lexicographically decreasing order
//
// We want a string-to-string mapping G(x) such that for any two strings,
// whether finite or not,
//
//      x < y   =>   G(x) > G(y)
//
// To achieve this, define G(x) to be the inversion of F(x): I(F(x)).  In
// other words, invert every bit in F(x) to get G(x). For example,
//
//        x  = \x00\x13\xff
//      F(x) = \x00\xff\x13\xff\x00\x00\x01  escape \0, \xff, append F(<sep>)
//      G(x) = \xff\x00\xec\x00\xff\xff\xfe  invert every bit in F(x)
//
//        x  = <infinity>
//      F(x) = \xff\xff
//      G(x) = \x00\x00
//
// Another example is
//
//        x            F(x)        G(x) = I(F(x))
//        -            ----        --------------
//        <infinity>   \xff\xff    \x00\x00
//        "foo"        foo\0\1     \x99\x90\x90\xff\xfe
//        "aaa"        aaa\0\1     \x9e\x9e\x9e\xff\xfe
//        "aa"         aa\0\1      \x9e\x9e\xff\xfe
//        ""           \0\1        \xff\xfe
//
// More generally and rigorously, if for any two strings x and y
//
//      F(x) < F(y)   =>   I(F(x)) > I(F(y))                      (1)
//
// it would follow that x < y => G(x) > G(y) because
//
//      x < y   =>   F(x) < F(y)   =>   G(x) = I(F(x)) > I(F(y)) = G(y)
//
// We now show why (1) is true, in two parts.  Notice that for any two
// strings x < y, F(x) is *not* a proper prefix of F(y).  Suppose x is a
// proper prefix of y (say, x="abc" < y="abcd").  F(x) and F(y) diverge at
// the F(<sep>) in F(x) (v. F('d') in the example).  Suppose x is not a
// proper prefix of y (say, x="abce" < y="abd"), F(x) and F(y) diverge at
// their respective encodings of the characters where x and y diverge
// (F('c') v. F('d')).  Finally, if y=<infinity>, we can see that
// F(y)=\xff\xff is not the prefix of F(x) for any finite string x, simply
// by considering all the possible first characters of F(x).
//
// Given that F(x) is not a proper prefix F(y), the order of F(x) and F(y)
// is determined by the byte where F(x) and F(y) diverge.  For example, the
// order of F(x)="eefh" and F(y)="eeg" is determined by their third
// characters.  I(p) inverts each byte in p, which effectively subtracts
// each byte from 0xff.  So, in this example, I('f') > I('g'), and thus
// I(F(x)) > I(F(y)).
//
//
// Implementation
//
// To implement G(x) efficiently, we use C++ template to instantiate two
// versions of the code to produce F(x), one for normal encoding (giving us
// F(x)) and one for inverted encoding (giving us G(x) = I(F(x))).

namespace firebase {
namespace firestore {
namespace util {

static const char kEscape1 = '\000';
static const char kNullCharacter = '\xff';  // Combined with kEscape1
static const char kSeparator = '\001';      // Combined with kEscape1

static const char kEscape2 = '\xff';
static const char kInfinity = '\xff';     // Combined with kEscape2
static const char kFFCharacter = '\000';  // Combined with kEscape2

static const char kEscape1_Separator[2] = {kEscape1, kSeparator};

// Return the byte ~x if INVERT, the byte x itself if not.  We expect 'x'
// to be a compile-time constant and the whole "function" to be inlined
// into another compiler-time constant.
template <bool INVERT>
inline static constexpr char Convert(char x) {
  return INVERT ? ~x : x;
}

template <bool INVERT>
inline static constexpr uint16_t Convert(uint16_t x) {
  return INVERT ? ~x : x;
}

template <bool INVERT>
inline static constexpr uint32_t Convert(uint32_t x) {
  return INVERT ? ~x : x;
}

template <bool INVERT>
inline static constexpr uint64_t Convert(uint64_t x) {
  return INVERT ? ~x : x;
}

template <bool INVERT>
inline static uint16_t Convert(char a, char b) {
  auto ua = static_cast<unsigned char>(a);
  auto ub = static_cast<unsigned char>(b);
#ifdef ABSL_IS_LITTLE_ENDIAN
  uint16_t x = static_cast<uint16_t>(ua) | (static_cast<uint16_t>(ub) << 8);
#else
  uint16 x = (static_cast<uint16>(ua) << 8) | static_cast<uint16>(ub);
#endif
  return INVERT ? ~x : x;
}
// Copy to "*dest" the "len" bytes starting from "*src", with each byte
// inverted
template <bool INVERT>
inline void CopyInvertedBytes(char* dst, const char* src, size_t len) {
  switch (len) {
    case 0:
      return;
    case 1:
      *dst = Convert<INVERT>(*src);
      return;
    case 3:
      *(dst + 2) = Convert<INVERT>(*(src + 2));
      ABSL_FALLTHROUGH_INTENDED;
    case 2:
      UNALIGNED_STORE16(dst, Convert<INVERT>(UNALIGNED_LOAD16(src)));
      return;
    case 5:
    case 6:
    case 7:
      UNALIGNED_STORE32(dst + len - 4,
                        Convert<INVERT>(UNALIGNED_LOAD32(src + len - 4)));
      ABSL_FALLTHROUGH_INTENDED;
    case 4:
      UNALIGNED_STORE32(dst, Convert<INVERT>(UNALIGNED_LOAD32(src)));
      return;
    default:
      for (size_t done = 0; done < len - 8; done += 8) {
        UNALIGNED_STORE64(dst + done,
                          Convert<INVERT>(UNALIGNED_LOAD64(src + done)));
      }
      UNALIGNED_STORE64(dst + len - 8,
                        Convert<INVERT>(UNALIGNED_LOAD64(src + len - 8)));
  }
}

// Append to "*dest" the "len" bytes starting from "*src", with inversion
// iff INVERT is true.
template <bool INVERT>
void AppendBytes(std::string* dest, const char* src, size_t len) {
  const size_t old_size = dest->size();
  absl::strings_internal::STLStringResizeUninitialized(dest, old_size + len);
  CopyInvertedBytes<INVERT>(&(*dest)[old_size], src, len);
}

inline bool IsSpecialByte(char c) {
  return ((unsigned char)(c + 1)) < 2;
}

// Returns 0 if one or more of the bytes in the specified uint32 value
// are the special values 0 or 255, and returns 4 otherwise.  The
// result of this routine can be added to "p" to either advance past
// the next 4 bytes if they do not contain a special byte, or to
// remain on this set of four bytes if they contain the next special
// byte occurrence.
//
// REQUIRES: v is the value of loading the next 4 bytes from "*p" (we
// pass in v rather than loading it because in some cases, the client
// may already have the value in a register: "p" is just used for
// assertion checking).
inline int AdvanceIfNoSpecialBytes(uint32_t v_32, const char* p) {
  HARD_ASSERT(UNALIGNED_LOAD32(p) == v_32);
  // See comments in SkipToNextSpecialByte if you wish to
  // understand this expression (which checks for the occurrence
  // of the special byte values 0 or 255 in any of the bytes of v_32).
  if ((v_32 - 0x01010101u) & ~(v_32 + 0x01010101u) & 0x80808080u) {
    // Special byte is in p[0..3]
    HARD_ASSERT(IsSpecialByte(p[0]) || IsSpecialByte(p[1]) ||
                IsSpecialByte(p[2]) || IsSpecialByte(p[3]));
    return 0;
  } else {
    HARD_ASSERT(!IsSpecialByte(p[0]));
    HARD_ASSERT(!IsSpecialByte(p[1]));
    HARD_ASSERT(!IsSpecialByte(p[2]));
    HARD_ASSERT(!IsSpecialByte(p[3]));
    return 4;
  }
}

// Return a pointer to the first byte in the range "[start..limit)"
// whose value is 0 or 255 (kEscape1 or kEscape2).  If no such byte
// exists in the range, returns "limit".
inline const char* SkipToNextSpecialByte(const char* start, const char* limit) {
  // If these constants were ever changed, this routine needs to change
  static_assert(kEscape1 == 0, "bit fiddling needs readjusting");
  static_assert((kEscape2 & 0xff) == 255, "bit fiddling needs readjusting");
  const char* p = start;
  while (p + 8 <= limit) {
    // Find out if any of the next 8 bytes are either 0 or 255 (our
    // two characters that require special handling).  We do this using
    // the technique described in:
    //
    //    http://graphics.stanford.edu/~seander/bithacks.html#HasLessInWord
    //
    // We use the test (x + 1) < 2 to check x = 0 or -1(255)
    //
    // If x is a byte value (0x00..0xff):
    // (x - 0x01) & 0x80 is true only when x = 0x81..0xff, 0x00
    // ~(x + 0x01) & 0x80 is true only when x = 0x00..0x7e, 0xff
    // The intersection of the above two sets is x = 0x00 or 0xff.
    // We can ignore carry between bytes because only x = 0x00 or 0xff
    // can cause carry in the expression -- and such x already makes the
    // result value non-zero.
    uint64_t v = UNALIGNED_LOAD64(p);
    bool hasZeroOr255Byte = (v - 0x0101010101010101ull) &
                            ~(v + 0x0101010101010101ull) &
                            0x8080808080808080ull;
    if (!hasZeroOr255Byte) {
      // No special values in the next 8 bytes
      p += 8;
    } else {
      // We know the next 8 bytes have a special byte: find it
#ifdef ABSL_IS_LITTLE_ENDIAN
      uint32_t v_32 = static_cast<uint32_t>(v);  // Low 32 bits of v
#else
      uint32_t v_32 = UNALIGNED_LOAD32(p);
#endif
      // Test 32 bits at once to see if special byte is in next 4 bytes
      // or the following 4 bytes
      p += AdvanceIfNoSpecialBytes(v_32, p);
      if (IsSpecialByte(p[0])) return p;
      if (IsSpecialByte(p[1])) return p + 1;
      if (IsSpecialByte(p[2])) return p + 2;
      HARD_ASSERT(IsSpecialByte(p[3]));  // Last byte must be the special one
      return p + 3;
    }
  }
  if (p + 4 <= limit) {
    uint32_t v_32 = UNALIGNED_LOAD32(p);
    p += AdvanceIfNoSpecialBytes(v_32, p);
  }
  while (p < limit && !IsSpecialByte(*p)) {
    p++;
  }
  return p;
}

// Expose SkipToNextSpecialByte for testing purposes
const char* OrderedCode::TEST_SkipToNextSpecialByte(const char* start,
                                                    const char* limit) {
  return SkipToNextSpecialByte(start, limit);
}

// Helper routine to encode "s" and append to "*dest", escaping special
// characters.  Invert the output iff INVERT is true.
template <bool INVERT>
inline static void EncodeStringFragment(std::string* dest,
                                        absl::string_view s) {
  if (s.empty()) return;

  const char* p = s.data();
  const char* const limit = p + s.size();
  const char* copy_start = p;

  while (true) {
    p = SkipToNextSpecialByte(p, limit);
    if (p >= limit) break;  // No more special characters that need escaping
    HARD_ASSERT(IsSpecialByte(*p));
    AppendBytes<INVERT>(dest, copy_start, p - copy_start);
    char c = *p;
    // This is either:
    //   kEscape1, kNullCharacter or,
    //   kEscape2, kFFCharacter
    // Recall that kEscape1 == ~kNullCharacter and kEscape2 == ~kFFCharacter.
    const char tmp[2] = {Convert<INVERT>(c), Convert<!INVERT>(c)};
    dest->append(tmp, 2);
    copy_start = ++p;
  }
  if (p > copy_start) {
    AppendBytes<INVERT>(dest, copy_start, p - copy_start);
  }
}

void OrderedCode::WriteString(std::string* dest, absl::string_view s) {
  EncodeStringFragment<false>(dest, s);
  AppendBytes<false>(dest, kEscape1_Separator, 2);
}

void OrderedCode::WriteStringDecreasing(std::string* dest,
                                        absl::string_view s) {
  EncodeStringFragment<true>(dest, s);
  AppendBytes<true>(dest, kEscape1_Separator, 2);
}

// Return number of bytes needed to encode the non-length portion
// of val in ordered coding.  Returns number in range [0,8].
static inline unsigned int OrderedNumLength(uint64_t val) {
  const int lg = Bits::Log2Floor64(val);  // -1 if val==0
  return static_cast<unsigned int>(lg + 1 + 7) / 8;
}

// Append n bytes from src to *dst.
// REQUIRES: n <= 9
// REQUIRES: src[0..8] are readable bytes (even if n is smaller)
//
// If we use string::append() instead of this routine, it increases the
// runtime of WriteNumIncreasingSmall/WriteNumDecreasingSmall from ~7ns to
// ~13ns.
static inline void AppendUpto9(std::string* dst,
                               const char* src,
                               unsigned int n) {
  const size_t old_size = dst->size();
  absl::strings_internal::STLStringResizeUninitialized(dst, old_size + 9);
  memcpy(&(*dst)[old_size], src, 9);
  dst->erase(old_size + n);
}

void OrderedCode::WriteNumIncreasing(std::string* dest, uint64_t val) {
  // Values are encoded with a single byte length prefix, followed
  // by the actual value in big-endian format with leading 0 bytes
  // dropped.

  // 8 bytes for value plus one byte for length.  In addition, we have
  // 8 extra bytes at the end so that we can have a fixed-length append
  // call on *dest.
  char buf[17];

  UNALIGNED_STORE64(buf + 1,
                    absl::ghtonll(val));  // buf[0] may be needed for length
  const unsigned int length = OrderedNumLength(val);
  char* start = buf + 9 - length - 1;
  *start = static_cast<char>(length);
  AppendUpto9(dest, start, length + 1);
}

void OrderedCode::WriteNumDecreasing(std::string* dest, uint64_t val) {
  // Values are encoded with a single byte length prefix, followed
  // by the actual value in big-endian format with leading 0 bytes
  // dropped.

  // 8 bytes for value plus one byte for length.  In addition, we have
  // 8 extra bytes at the end so that we can have a fixed-length append
  // call on *dest.
  char buf[17];

  UNALIGNED_STORE64(buf + 1,
                    absl::ghtonll(~val));  // buf[0] may be needed for length
  const unsigned int length = OrderedNumLength(val);
  char* start = buf + 9 - length - 1;
  *start = static_cast<char>(~length);
  AppendUpto9(dest, start, length + 1);
}

template <bool INVERT>
inline static void WriteInfinityInternal(std::string* dest) {
  // Make an array so that we can just do one string operation for performance
  static constexpr char buf[2] = {Convert<INVERT>(kEscape2),
                                  Convert<INVERT>(kInfinity)};
  dest->append(buf, 2);
}

void OrderedCode::WriteInfinity(std::string* dest) {
  WriteInfinityInternal<false>(dest);
}

void OrderedCode::WriteInfinityDecreasing(std::string* dest) {
  WriteInfinityInternal<true>(dest);
}

void OrderedCode::WriteTrailingString(std::string* dest,
                                      absl::string_view str) {
  dest->append(str.data(), str.size());
}

// Parse the encoding of a string previously encoded with or without
// inversion.  If parse succeeds, return true, consume encoding from
// "*src", and if result != NULL append the decoded string to "*result".
// Otherwise, return false and leave both undefined.

template <bool INVERT>
inline static bool ReadStringInternal(absl::string_view* src,
                                      std::string* result) {
  const char* p = src->data();
  const char* string_limit = src->data() + src->size();

  // We only scan up to "limit-2" since a valid string must end with
  // a two character terminator: 'kEscape1 kSeparator'
  const char* const end = string_limit - 1;
  const char* copy_start = p;
  while (true) {
    p = SkipToNextSpecialByte(p, end);
    if (p >= end) return false;  // No terminator sequence found
    HARD_ASSERT(IsSpecialByte(*p));
    if (result) {
      AppendBytes<INVERT>(result, copy_start, p - copy_start);
    }
    // Load the sequence of both the escape and the next character. There are
    // only 3 valid cases to check and this avoids complicated branches.
    const uint16_t seq = UNALIGNED_LOAD16(p);
    // If inversion is required, instead of inverting the sequence we invert the
    // constants to which it is compared. This avoids the runtime overhead.
    if (seq == Convert<INVERT>(kEscape1, kSeparator)) {
      // kEscape1 kSeparator ends component.
      src->remove_prefix(p - src->data() + 2);
      return true;
    } else if (seq == Convert<INVERT>(kEscape1, kNullCharacter)) {
      // kEscape1 kNullCharacter represents '\0'.
      if (result) {
        *result += '\0';
      }
    } else if (seq == Convert<INVERT>(kEscape2, kFFCharacter)) {
      // kEscape2 kFFCharacter represents '\xff'.
      if (result) {
        *result += '\xff';
      }
    } else {
      // Anything else is an error.
      return false;
    }
    p += 2;
    copy_start = p;
  }
}

bool OrderedCode::ReadString(absl::string_view* src, std::string* result) {
  return ReadStringInternal<false>(src, result);
}

bool OrderedCode::ReadStringDecreasing(absl::string_view* src,
                                       std::string* result) {
  return ReadStringInternal<true>(src, result);
}

bool OrderedCode::ReadNumIncreasing(absl::string_view* src, uint64_t* result) {
  if (src->empty()) {
    return false;  // Not enough bytes
  }

  // Decode length byte
  const size_t len = static_cast<size_t>((*src)[0]);

  // If len > 0 and src is longer than 1, the first byte of "payload"
  // must be non-zero (otherwise the encoding is not minimal).
  // In opt mode, we don't enforce that encodings must be minimal.
  HARD_ASSERT(0 == len || src->size() == 1 || (*src)[1] != '\0');

  if (len + 1 > src->size() || len > 8) {
    return false;  // Not enough bytes or too many bytes
  }

  if (result) {
    uint64_t tmp = 0;
    for (size_t i = 0; i < len; i++) {
      tmp <<= 8;
      tmp |= static_cast<unsigned char>((*src)[1 + i]);
    }
    *result = tmp;
  }
  src->remove_prefix(len + 1);
  return true;
}

bool OrderedCode::ReadNumDecreasing(absl::string_view* src, uint64_t* result) {
  if (src->empty()) {
    return false;  // Not enough bytes
  }

  const size_t len = static_cast<size_t>(~(*src)[0]);

  // If len > 0 and src is longer than 1, the first byte of "payload"
  // must be non-~zero (otherwise the encoding is not minimal).
  // In opt mode, we don't enforce that encodings must be minimal.
  HARD_ASSERT(0 == len || src->size() == 1 || (*src)[1] != '\xff');

  if (len + 1 > src->size() || len > 8) {
    return false;  // Not enough bytes or too many bytes
  }

  if (result) {
    uint64_t tmp = 0;
    if (len != 0) {
      tmp = ~(0ull);
      for (size_t i = 0; i < len;) {
        tmp <<= 8;
        tmp |= static_cast<unsigned char>((*src)[++i]);
      }
      tmp = ~tmp;
    }
    *result = tmp;
  }
  src->remove_prefix(len + 1);
  return true;
}

template <bool INVERT>
inline static bool ReadInfinityInternal(absl::string_view* src) {
  if (src->size() >= 2 && ((*src)[0] == Convert<INVERT>(kEscape2)) &&
      ((*src)[1] == Convert<INVERT>(kInfinity))) {
    src->remove_prefix(2);
    return true;
  } else {
    return false;
  }
}

bool OrderedCode::ReadInfinity(absl::string_view* src) {
  return ReadInfinityInternal<false>(src);
}

bool OrderedCode::ReadInfinityDecreasing(absl::string_view* src) {
  return ReadInfinityInternal<true>(src);
}

template <bool INVERT>
inline static bool ReadStringOrInfinityInternal(absl::string_view* src,
                                                std::string* result,
                                                bool* inf) {
  if (ReadInfinityInternal<INVERT>(src)) {
    if (inf) *inf = true;
    return true;
  }

  // We don't use ReadStringInternal<INVERT> here because that would inline
  // the whole encoded string parsing code here.  Depending on INVERT, only
  // one of the following two calls will be generated at compile time.
  bool success;
  if (INVERT) {
    success = OrderedCode::ReadStringDecreasing(src, result);
  } else {
    success = OrderedCode::ReadString(src, result);
  }
  if (success) {
    if (inf) *inf = false;
    return true;
  } else {
    return false;
  }
}

bool OrderedCode::ReadStringOrInfinity(absl::string_view* src,
                                       std::string* result,
                                       bool* inf) {
  return ReadStringOrInfinityInternal<false>(src, result, inf);
}

bool OrderedCode::ReadStringOrInfinityDecreasing(absl::string_view* src,
                                                 std::string* result,
                                                 bool* inf) {
  return ReadStringOrInfinityInternal<true>(src, result, inf);
}

bool OrderedCode::ReadTrailingString(absl::string_view* src,
                                     std::string* result) {
  if (result) result->assign(src->data(), src->size());
  src->remove_prefix(src->size());
  return true;
}

void OrderedCode::TEST_Corrupt(std::string* str, int k) {
  int seen_seps = 0;
  for (size_t i = 0; i < str->size() - 1; i++) {
    if ((*str)[i] == kEscape1 && (*str)[i + 1] == kSeparator) {
      seen_seps++;
      if (seen_seps == k) {
        (*str)[i + 1] = kSeparator + 1;
        return;
      }
    }
  }
}

// Signed number encoding/decoding /////////////////////////////////////
//
// The format is as follows:
//
// The first bit (the most significant bit of the first byte)
// represents the sign, 0 if the number is negative and
// 1 if the number is >= 0.
//
// Any unbroken sequence of successive bits with the same value as the sign
// bit, up to 9 (the 8th and 9th are the most significant bits of the next
// byte), are size bits that count the number of bytes after the first byte.
// That is, the total length is between 1 and 10 bytes.
//
// The value occupies the bits after the sign bit and the "size bits"
// till the end of the string, in network byte order.  If the number
// is negative, the bits are in 2-complement.
//
//
// Example 1: number 0x424242 -> 4 byte big-endian hex string 0xf0424242:
//
// +---------------+---------------+---------------+---------------+
//  1 1 1 1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0 0 0 0 1 0 0 1 0 0 0 0 1 0
// +---------------+---------------+---------------+---------------+
//  ^ ^ ^ ^   ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^
//  | | | |   | | | | | | | | | | | | | | | | | | | | | | | | | | |
//  | | | |   payload: the remaining bits after the sign and size bits
//  | | | |            and the delimiter bit, the value is 0x424242
//  | | | |
//  | size bits: 3 successive bits with the same value as the sign bit
//  |            (followed by a delimiter bit with the opposite value)
//  |            mean that there are 3 bytes after the first byte, 4 total
//  |
//  sign bit: 1 means that the number is non-negative
//
// Example 2: negative number -0x800 -> 2 byte big-endian hex string 0x3800:
//
// +---------------+---------------+
//  0 0 1 1 1 0 0 0 0 0 0 0 0 0 0 0
// +---------------+---------------+
//  ^ ^   ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ ^
//  | |   | | | | | | | | | | | | | | | | | | | | | | | | | | |
//  | |   payload: the remaining bits after the sign and size bits and the
//  | |            delimiter bit, 2-complement because of the negative sign,
//  | |            value is ~0x7ff, represents the value -0x800
//  | |
//  | size bits: 1 bit with the same value as the sign bit
//  |            (followed by a delimiter bit with the opposite value)
//  |            means that there is 1 byte after the first byte, 2 total
//  |
//  sign bit: 0 means that the number is negative
//
//
// Compared with the simpler unsigned format used for uint64 numbers,
// this format is more compact for small numbers, namely one byte encodes
// numbers in the range [-64,64), two bytes cover the range [-2^13,2^13), etc.
// In general, n bytes encode numbers in the range [-2^(n*7-1),2^(n*7-1)).
// (The cross-over point for compactness of representation is 8 bytes,
// where this format only covers the range [-2^55,2^55),
// whereas an encoding with sign bit and length in the first byte and
// payload in all following bytes would cover [-2^56,2^56).)

static const int kMaxSigned64Length = 10;

// This array maps encoding length to header bits in the first two bytes.
static const char kLengthToHeaderBits[1 + kMaxSigned64Length][2] = {
    {0, 0},      {'\x80', 0},      {'\xc0', 0},     {'\xe0', 0},
    {'\xf0', 0}, {'\xf8', 0},      {'\xfc', 0},     {'\xfe', 0},
    {'\xff', 0}, {'\xff', '\x80'}, {'\xff', '\xc0'}};

// This array maps encoding lengths to the header bits that overlap with
// the payload and need fixing when reading.
static const uint64_t kLengthToMask[1 + kMaxSigned64Length] = {
    0ULL,
    0x80ULL,
    0xc000ULL,
    0xe00000ULL,
    0xf0000000ULL,
    0xf800000000ULL,
    0xfc0000000000ULL,
    0xfe000000000000ULL,
    0xff00000000000000ULL,
    0x8000000000000000ULL,
    0ULL};

// This array maps the number of bits in a number to the encoding
// length produced by WriteSignedNumIncreasing.
// For positive numbers, the number of bits is 1 plus the most significant
// bit position (the highest bit position in a positive int64 is 63).
// For a negative number n, we count the bits in ~n.
// That is, length = kBitsToLength[Bits::Log2Floor64(n < 0 ? ~n : n) + 1].
static const int8_t kBitsToLength[1 + 63] = {
    1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4,
    4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6, 6, 7, 7,
    7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9, 9, 9, 9, 9, 10};

// Calculates the encoding length in bytes of the signed number n.
static inline int SignedEncodingLength(int64_t n) {
  return kBitsToLength[Bits::Log2Floor64(n < 0 ? ~n : n) + 1];
}

// Slightly faster version for n > 0.
static inline int SignedEncodingLengthPositive(int64_t n) {
  return kBitsToLength[Bits::Log2FloorNonZero64(n) + 1];
}

void OrderedCode::WriteSignedNumIncreasing(std::string* dest, int64_t val) {
  const uint64_t x = val < 0 ? ~val : val;
  if (x < 64) {  // fast path for encoding length == 1
    *dest += kLengthToHeaderBits[1][0] ^ val;
    return;
  }
  // buf = val in network byte order, sign extended to 10 bytes
  const char sign_byte = val < 0 ? '\xff' : '\0';
  char buf[10] = {
      sign_byte,
      sign_byte,
  };
  UNALIGNED_STORE64(buf + 2, absl::ghtonll(val));
  static_assert(sizeof(buf) == kMaxSigned64Length, "max_length_size_mismatch");
  const int len = SignedEncodingLengthPositive(x);
  HARD_ASSERT(len >= 2);
  char* const begin = buf + sizeof(buf) - len;
  begin[0] ^= kLengthToHeaderBits[len][0];
  begin[1] ^= kLengthToHeaderBits[len][1];  // ok because len >= 2
  dest->append(begin, len);
}

bool OrderedCode::ReadSignedNumIncreasing(absl::string_view* src,
                                          int64_t* result) {
  if (src->empty()) return false;
  const uint64_t xor_mask = (!((*src)[0] & 0x80)) ? ~0ULL : 0ULL;
  const unsigned char first_byte = (*src)[0] ^ (xor_mask & 0xff);

  // now calculate and test length, and set x to raw (unmasked) result
  int len;
  uint64_t x;
  if (first_byte != 0xff) {
    len = 7 - Bits::Log2FloorNonZero(first_byte ^ 0xff);
    if (static_cast<int64_t>(src->size()) < len) return false;
    x = xor_mask;  // sign extend using xor_mask
    for (int i = 0; i < len; ++i)
      x = (x << 8) | static_cast<unsigned char>((*src)[i]);
  } else {
    len = 8;
    if (static_cast<int64_t>(src->size()) < len) return false;
    const unsigned char second_byte = (*src)[1] ^ (xor_mask & 0xff);
    if (second_byte >= 0x80) {
      if (second_byte < 0xc0) {
        len = 9;
      } else {
        const unsigned char third_byte = (*src)[2] ^ (xor_mask & 0xff);
        if (second_byte == 0xc0 && third_byte < 0x80) {
          len = 10;
        } else {
          return false;  // either len > 10 or len == 10 and #bits > 63
        }
      }
      if (static_cast<int64_t>(src->size()) < len) return false;
    }
    x = absl::gntohll(UNALIGNED_LOAD64(src->data() + len - 8));
  }

  x ^= kLengthToMask[len];  // remove spurious header bits

  HARD_ASSERT(len == SignedEncodingLength(x));

  if (result) *result = x;
  src->remove_prefix(len);
  return true;
}

// Double encoding/decoding //////////////////////////////////////////////
//
// http://en.wikipedia.org/wiki/IEEE_754-1985
// Read this first.  You are going to need it.
//
// The standard specifies a double-precision 64-bit number:
//   sign:     1 bit
//   exponent: 11 bits
//   fraction: 52 bits
//
// There are five categories of number:
//   zero:      sign = any, exponent = all 0, fraction = 0
//   denormal:  sign = any, exponent = all 0, fraction > 0
//   normal:    sign = any, exponent = most,  fraction = any
//   infinity:  sign = any, exponent = all 1, fraction = 0
//   NaN:       sign = any, exponent = all 1, fraction > 0
//
// We translate positive doubles to int64 with a straight bit-cast.
//
// We translate negative doubles to int64 by keeping the sign bit
// and reversing the other bits.  Except -0 which is special.
//
// The ordering of encoded doubles is:
//
//   double     int64
//
//   -NaN       # 0x800x_xxxx_xxxx_xxxx  (x not all 0)
//   -infinity  # 0x8010_0000_0000_0000
//   -normal
//   -denormal  # 0xFFFF_FFFF_FFFF_FFFF  (denormal closest to -zero)
//   -zero      # 0x0000_0000_0000_0000
//   +zero      # 0x0000_0000_0000_0000
//   +denormal  # 0x0000_0000_0000_0001  (denormal closest to +zero)
//   +normal
//   +infinity  # 0x7FF0_0000_0000_0000
//   +NaN       # 0x7FFx_xxxx_xxxx_xxxx  (x not all 0)
//
// Both -zero and +zero encode to 0x0000_0000_0000_0000.
// No value encodes to 0x8000_0000_0000_0000.
//
// Both 0x0000_0000_0000_000 and 0x8000_0000_0000_000 decode to +zero.
// No value decodes to -zero.

inline static int64_t EncodeDoubleAsInt64(double num) {
  int64_t enc = absl::bit_cast<int64_t>(num);
  if (enc < 0) {
    enc = std::numeric_limits<int64_t>::min() - enc;
  }
  return enc;
}

inline static void DecodeDoubleFromInt64(int64_t enc, double* result) {
  if (enc < 0) {
    enc = std::numeric_limits<int64_t>::min() - enc;
  }
  *result = absl::bit_cast<double>(enc);
}

void OrderedCode::WriteDoubleIncreasing(std::string* dest, double num) {
  OrderedCode::WriteSignedNumIncreasing(dest, EncodeDoubleAsInt64(num));
}

void OrderedCode::WriteDoubleDecreasing(std::string* dest, double num) {
  OrderedCode::WriteSignedNumDecreasing(dest, EncodeDoubleAsInt64(num));
}

bool OrderedCode::ReadDoubleIncreasing(absl::string_view* src, double* result) {
  int64_t enc = 0;
  if (!OrderedCode::ReadSignedNumIncreasing(src, &enc)) {
    return false;
  }
  DecodeDoubleFromInt64(enc, result);
  return true;
}

bool OrderedCode::ReadDoubleDecreasing(absl::string_view* src, double* result) {
  int64_t enc = 0;
  if (!OrderedCode::ReadSignedNumDecreasing(src, &enc)) {
    return false;
  }
  DecodeDoubleFromInt64(enc, result);
  return true;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
