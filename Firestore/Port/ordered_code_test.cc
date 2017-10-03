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

#include "ordered_code.h"

// #include <float.h>
// #include <stddef.h>
#include <iostream>
#include <limits>

#include "base/logging.h"
#include "testing/base/public/gunit.h"
#include <leveldb/db.h>
#include "util/random/acmrandom.h"

using Firestore::OrderedCode;
using leveldb::Slice;

// Make Slices writeable to ostream, making all the CHECKs happy below.
namespace {
void WritePadding(std::ostream& o, size_t pad) {
  char fill_buf[32];
  memset(fill_buf, o.fill(), sizeof(fill_buf));
  while (pad) {
    size_t n = std::min(pad, sizeof(fill_buf));
    o.write(fill_buf, n);
    pad -= n;
  }
}
}  // namespace

namespace leveldb {

std::ostream& operator<<(std::ostream& o, const Slice slice) {
  std::ostream::sentry sentry(o);
  if (sentry) {
    size_t lpad = 0;
    size_t rpad = 0;
    if (o.width() > slice.size()) {
      size_t pad = o.width() - slice.size();
      if ((o.flags() & o.adjustfield) == o.left) {
        rpad = pad;
      } else {
        lpad = pad;
      }
    }
    if (lpad) WritePadding(o, lpad);
    o.write(slice.data(), slice.size());
    if (rpad) WritePadding(o, rpad);
    o.width(0);
  }
  return o;
}

}  // namespace leveldb

static std::string RandomString(ACMRandom* rnd, int len) {
  std::string x;
  for (int i = 0; i < len; i++) {
    x += rnd->Uniform(256);
  }
  return x;
}

// ---------------------------------------------------------------------
// Utility template functions (they help templatize the tests below)

// Read/WriteIncreasing are defined for string, uint64_t, int64_t below.
template <typename T>
static void OCWriteIncreasing(std::string* dest, const T& val);
template <typename T>
static bool OCReadIncreasing(Slice* src, T* result);

// Read/WriteIncreasing<std::string>
template <>
void OCWriteIncreasing<std::string>(std::string* dest, const std::string& val) {
  OrderedCode::WriteString(dest, val);
}
template <>
bool OCReadIncreasing<std::string>(Slice* src, std::string* result) {
  return OrderedCode::ReadString(src, result);
}

// Read/WriteIncreasing<uint64_t>
template <>
void OCWriteIncreasing<uint64_t>(std::string* dest, const uint64_t& val) {
  OrderedCode::WriteNumIncreasing(dest, val);
}
template <>
bool OCReadIncreasing<uint64_t>(Slice* src, uint64_t* result) {
  return OrderedCode::ReadNumIncreasing(src, result);
}

enum Direction { INCREASING = 0 };

// Read/WriteIncreasing<int64_t>
template <>
void OCWriteIncreasing<int64_t>(std::string* dest, const int64_t& val) {
  OrderedCode::WriteSignedNumIncreasing(dest, val);
}
template <>
bool OCReadIncreasing<int64_t>(Slice* src, int64_t* result) {
  return OrderedCode::ReadSignedNumIncreasing(src, result);
}

template <typename T>
std::string OCWrite(T val, Direction direction) {
  std::string result;
  OCWriteIncreasing<T>(&result, val);
  return result;
}

template <typename T>
void OCWriteToString(std::string* result, T val, Direction direction) {
  OCWriteIncreasing<T>(result, val);
}

template <typename T>
bool OCRead(Slice* s, T* val, Direction direction) {
  return OCReadIncreasing<T>(s, val);
}

// ---------------------------------------------------------------------
// Numbers

template <typename T>
static T TestRead(Direction d, const std::string& a) {
  // gracefully reject any proper prefix of an encoding
  for (int i = 0; i < a.size() - 1; ++i) {
    Slice s(a.data(), i);
    CHECK(!OCRead<T>(&s, NULL, d));
    CHECK_EQ(s, a.substr(0, i));
  }

  Slice s(a);
  T v;
  CHECK(OCRead<T>(&s, &v, d));
  CHECK(s.empty());
  return v;
}

template <typename T>
static void TestWriteRead(Direction d, T expected) {
  EXPECT_EQ(expected, TestRead<T>(d, OCWrite<T>(expected, d)));
}

// Verifies that the second Write* call appends a non-empty std::string to its
// output.
template <typename T, typename U>
static void TestWriteAppends(Direction d, T first, U second) {
  std::string encoded;
  OCWriteToString<T>(&encoded, first, d);
  std::string encoded_first_only = encoded;
  OCWriteToString<U>(&encoded, second, d);
  EXPECT_NE(encoded, encoded_first_only);
  EXPECT_TRUE(Slice(encoded).starts_with(encoded_first_only));
}

template <typename T>
static void TestNumbers(T multiplier) {
  for (int j = 0; j < 2; ++j) {
    const Direction d = static_cast<Direction>(j);

    // first test powers of 2 (and nearby numbers)
    for (T x = std::numeric_limits<T>().max(); x != 0; x /= 2) {
      TestWriteRead(d, multiplier * (x - 1));
      TestWriteRead(d, multiplier * x);
      if (x != std::numeric_limits<T>::max()) {
        TestWriteRead(d, multiplier * (x + 1));
      } else if (multiplier < 0 && multiplier == -1) {
        TestWriteRead(d, -x - 1);
      }
    }

    ACMRandom rnd(301);
    for (int bits = 1; bits <= std::numeric_limits<T>().digits; ++bits) {
      // test random non-negative numbers with given number of significant bits
      const uint64_t mask = (~0ULL) >> (64 - bits);
      for (int i = 0; i < 1000; i++) {
        T x = rnd.Next64() & mask;
        TestWriteRead(d, multiplier * x);
        T y = rnd.Next64() & mask;
        TestWriteAppends(d, multiplier * x, multiplier * y);
      }
    }
  }
}

// Return true iff 'a' is "before" 'b' according to 'direction'
static bool CompareStrings(const std::string& a, const std::string& b,
                           Direction d) {
  return (INCREASING == d) ? (a < b) : (b < a);
}

template <typename T>
static void TestNumberOrdering() {
  const Direction d = INCREASING;

  // first the negative numbers (if T is signed, otherwise no-op)
  std::string laststr = OCWrite<T>(std::numeric_limits<T>().min(), d);
  for (T num = std::numeric_limits<T>().min() / 2; num != 0; num /= 2) {
    std::string strminus1 = OCWrite<T>(num - 1, d);
    std::string str = OCWrite<T>(num, d);
    std::string strplus1 = OCWrite<T>(num + 1, d);

    CHECK(CompareStrings(strminus1, str, d));
    CHECK(CompareStrings(str, strplus1, d));

    // Compare 'str' with 'laststr'.  When we approach 0, 'laststr' is
    // not necessarily before 'strminus1'.
    CHECK(CompareStrings(laststr, str, d));
    laststr = str;
  }

  // then the positive numbers
  laststr = OCWrite<T>(0, d);
  T num = 1;
  while (num < std::numeric_limits<T>().max() / 2) {
    num *= 2;
    std::string strminus1 = OCWrite<T>(num - 1, d);
    std::string str = OCWrite<T>(num, d);
    std::string strplus1 = OCWrite<T>(num + 1, d);

    CHECK(CompareStrings(strminus1, str, d));
    CHECK(CompareStrings(str, strplus1, d));

    // Compare 'str' with 'laststr'.
    CHECK(CompareStrings(laststr, str, d));
    laststr = str;
  }
}

// Helper routine for testing TEST_SkipToNextSpecialByte
static int FindSpecial(const std::string& x) {
  const char* p = x.data();
  const char* limit = p + x.size();
  const char* result = OrderedCode::TEST_SkipToNextSpecialByte(p, limit);
  return result - p;
}

TEST(OrderedCode, SkipToNextSpecialByte) {
  for (int len = 0; len < 256; len++) {
    ACMRandom rnd(301);
    std::string x;
    while (x.size() < len) {
      char c = 1 + rnd.Uniform(254);
      ASSERT_NE(c, 0);
      ASSERT_NE(c, 255);
      x += c;  // No 0 bytes, no 255 bytes
    }
    EXPECT_EQ(FindSpecial(x), x.size());
    for (int special_pos = 0; special_pos < len; special_pos++) {
      for (int special_test = 0; special_test < 2; special_test++) {
        const char special_byte = (special_test == 0) ? 0 : 255;
        std::string y = x;
        y[special_pos] = special_byte;
        EXPECT_EQ(FindSpecial(y), special_pos);
        if (special_pos < 16) {
          // Add some special bytes after the one at special_pos to make sure
          // we still return the earliest special byte in the string
          for (int rest = special_pos + 1; rest < len; rest++) {
            if (rnd.OneIn(3)) {
              y[rest] = rnd.OneIn(2) ? 0 : 255;
              EXPECT_EQ(FindSpecial(y), special_pos);
            }
          }
        }
      }
    }
  }
}

TEST(OrderedCode, ExhaustiveFindSpecial) {
  char buf[16];
  char* limit = buf + sizeof(buf);
  int count = 0;
  for (int start_offset = 0; start_offset <= 5; start_offset += 5) {
    // We test exhaustively with all combinations of 3 bytes starting
    // at offset 0 and offset 5 (so as to test with the bytes at both
    // ends of a 64-bit word).
    for (char& c : buf) {
      c = 'a';  // Not a special byte
    }
    for (int b0 = 0; b0 < 256; b0++) {
      for (int b1 = 0; b1 < 256; b1++) {
        for (int b2 = 0; b2 < 256; b2++) {
          buf[start_offset + 0] = b0;
          buf[start_offset + 1] = b1;
          buf[start_offset + 2] = b2;
          char* expected;
          if (b0 == 0 || b0 == 255) {
            expected = &buf[start_offset];
          } else if (b1 == 0 || b1 == 255) {
            expected = &buf[start_offset + 1];
          } else if (b2 == 0 || b2 == 255) {
            expected = &buf[start_offset + 2];
          } else {
            expected = limit;
          }
          count++;
          EXPECT_EQ(expected,
                    OrderedCode::TEST_SkipToNextSpecialByte(buf, limit));
        }
      }
    }
  }
  EXPECT_EQ(count, 256 * 256 * 256 * 2);
}

TEST(Uint64, EncodeDecode) { TestNumbers<uint64_t>(1); }

TEST(Uint64, Ordering) { TestNumberOrdering<uint64_t>(); }

TEST(Int64, EncodeDecode) {
  TestNumbers<int64_t>(1);
  TestNumbers<int64_t>(-1);
}

TEST(Int64, Ordering) { TestNumberOrdering<int64_t>(); }

// Returns the bitwise complement of s.
static inline std::string StrNot(const std::string& s) {
  std::string result;
  for (const char c : s) result.push_back(~c);
  return result;
}

template <typename T>
static void TestInvalidEncoding(Direction d, const std::string& s) {
  Slice p(s);
  EXPECT_FALSE(OCRead<T>(&p, static_cast<T*>(NULL), d));
  EXPECT_EQ(s, p);
}

TEST(OrderedCodeInvalidEncodingsTest, Overflow) {
  // 1U << 64, increasing
  const std::string k2xx64U = "\x09\x01" + std::string(8, 0);
  TestInvalidEncoding<uint64_t>(INCREASING, k2xx64U);

  // 1 << 63 and ~(1 << 63), increasing
  const std::string k2xx63 = "\xff\xc0\x80" + std::string(7, 0);
  TestInvalidEncoding<int64_t>(INCREASING, k2xx63);
  TestInvalidEncoding<int64_t>(INCREASING, StrNot(k2xx63));
}

TEST(OrderedCodeInvalidEncodingsTest, NonCanonical) {
  // Test DCHECK failures of "ambiguous"/"non-canonical" encodings.
  // These are non-minimal (but otherwise "valid") encodings that
  // differ from the minimal encoding chosen by OrderedCode::WriteXXX
  // and thus should be avoided to not mess up the string ordering of
  // encodings.

  ACMRandom rnd(301);

  for (int n = 2; n <= 9; ++n) {
    // The zero in non_minimal[1] is "redundant".
    std::string non_minimal =
        std::string(1, n - 1) + std::string(1, 0) + RandomString(&rnd, n - 2);
    EXPECT_EQ(n, non_minimal.length());

    EXPECT_NE(OCWrite<uint64_t>(0, INCREASING), non_minimal);
    if (DEBUG_MODE) {
      Slice s(non_minimal);
      EXPECT_DEATH_IF_SUPPORTED(OrderedCode::ReadNumIncreasing(&s, NULL),
                                "ssertion failed");
    } else {
      TestRead<uint64_t>(INCREASING, non_minimal);
    }
  }

  for (int n = 2; n <= 10; ++n) {
    // Header with 1 sign bit and n-1 size bits.
    std::string header =
        std::string(n / 8, 0xff) + std::string(1, 0xff << (8 - (n % 8)));
    // There are more than 7 zero bits between header bits and "payload".
    std::string non_minimal =
        header + std::string(1, rnd.Uniform(256) & ~*header.rbegin()) +
        RandomString(&rnd, n - header.length() - 1);
    EXPECT_EQ(n, non_minimal.length());

    EXPECT_NE(OCWrite<int64_t>(0, INCREASING), non_minimal);
    if (DEBUG_MODE) {
      Slice s(non_minimal);
      EXPECT_DEATH_IF_SUPPORTED(OrderedCode::ReadSignedNumIncreasing(&s, NULL),
                                "ssertion failed")
          << n;
      s = non_minimal;
    } else {
      TestRead<int64_t>(INCREASING, non_minimal);
    }
  }
}

// ---------------------------------------------------------------------
// Strings

TEST(String, Infinity) {
  const std::string value("\xff\xff foo");
  bool is_inf;
  std::string encoding, parsed;
  Slice s;

  // Check encoding/decoding of "infinity" for ascending order
  encoding.clear();
  OrderedCode::WriteInfinity(&encoding);
  encoding.push_back('a');
  s = encoding;
  EXPECT_TRUE(OrderedCode::ReadInfinity(&s));
  EXPECT_EQ(1, s.size());
  s = encoding;
  is_inf = false;
  EXPECT_TRUE(OrderedCode::ReadStringOrInfinity(&s, NULL, &is_inf));
  EXPECT_EQ(1, s.size());
  EXPECT_TRUE(is_inf);

  // Check ReadStringOrInfinity() can parse ordinary strings
  encoding.clear();
  OrderedCode::WriteString(&encoding, value);
  encoding.push_back('a');
  s = encoding;
  is_inf = false;
  parsed.clear();
  EXPECT_TRUE(OrderedCode::ReadStringOrInfinity(&s, &parsed, &is_inf));
  EXPECT_EQ(1, s.size());
  EXPECT_FALSE(is_inf);
  EXPECT_EQ(value, parsed);
}

TEST(String, EncodeDecode) {
  ACMRandom rnd(301);
  for (int i = 0; i < 2; ++i) {
    const Direction d = static_cast<Direction>(i);

    for (int len = 0; len < 256; len++) {
      const std::string a = RandomString(&rnd, len);
      TestWriteRead(d, a);
      for (int len2 = 0; len2 < 64; len2++) {
        const std::string b = RandomString(&rnd, len2);

        TestWriteAppends(d, a, b);

        std::string out;
        OCWriteToString<std::string>(&out, a, d);
        OCWriteToString<std::string>(&out, b, d);

        std::string a2, b2, dummy;
        Slice s = out;
        Slice s2 = out;
        CHECK(OCRead<std::string>(&s, &a2, d));
        CHECK(OCRead<std::string>(&s2, NULL, d));
        CHECK_EQ(s, s2);

        CHECK(OCRead<std::string>(&s, &b2, d));
        CHECK(OCRead<std::string>(&s2, NULL, d));
        CHECK_EQ(s, s2);

        CHECK(!OCRead<std::string>(&s, &dummy, d));
        CHECK(!OCRead<std::string>(&s2, NULL, d));
        CHECK_EQ(a, a2);
        CHECK_EQ(b, b2);
        CHECK(s.empty());
        CHECK(s2.empty());
      }
    }
  }
}

// 'str' is a static C-style string that may contain '\0'
#define STATIC_STR(str) Slice((str), sizeof(str) - 1)

static std::string EncodeStringIncreasing(Slice value) {
  std::string encoded;
  OrderedCode::WriteString(&encoded, value);
  return encoded;
}

TEST(String, Increasing) {
  // Here are a series of strings in non-decreasing order, including
  // consecutive strings such that the second one is equal to, a proper
  // prefix of, or has the same length as the first one.  Most also contain
  // the special escaping characters '\x00' and '\xff'.
  ASSERT_EQ(EncodeStringIncreasing(STATIC_STR("")),
            EncodeStringIncreasing(STATIC_STR("")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("")),
            EncodeStringIncreasing(STATIC_STR("\x00")));

  ASSERT_EQ(EncodeStringIncreasing(STATIC_STR("\x00")),
            EncodeStringIncreasing(STATIC_STR("\x00")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("\x00")),
            EncodeStringIncreasing(STATIC_STR("\x01")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("\x01")),
            EncodeStringIncreasing(STATIC_STR("a")));

  ASSERT_EQ(EncodeStringIncreasing(STATIC_STR("a")),
            EncodeStringIncreasing(STATIC_STR("a")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("a")),
            EncodeStringIncreasing(STATIC_STR("aa")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("aa")),
            EncodeStringIncreasing(STATIC_STR("\xff")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("\xff")),
            EncodeStringIncreasing(STATIC_STR("\xff\x00")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("\xff\x00")),
            EncodeStringIncreasing(STATIC_STR("\xff\x01")));

  std::string infinity;
  OrderedCode::WriteInfinity(&infinity);
  ASSERT_LT(EncodeStringIncreasing(std::string(1 << 20, '\xff')), infinity);
}
