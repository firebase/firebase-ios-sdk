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

#include <iostream>
#include <limits>

#include "Firestore/core/src/util/secure_random.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

static std::string RandomString(SecureRandom* rnd, int len) {
  std::string x;
  for (int i = 0; i < len; i++) {
    x += static_cast<char>(rnd->Uniform(256));
  }
  return x;
}

// ---------------------------------------------------------------------
// Utility template functions (they help templatize the tests below)

// Read/WriteIncreasing are defined for string, uint64_t, int64_t below.
template <typename T>
static void OCWriteIncreasing(std::string* dest, const T& val);
template <typename T>
static bool OCReadIncreasing(absl::string_view* src, T* result);

// Read/WriteIncreasing<std::string>
template <>
void OCWriteIncreasing<std::string>(std::string* dest, const std::string& val) {
  OrderedCode::WriteString(dest, val);
}
template <>
bool OCReadIncreasing<std::string>(absl::string_view* src,
                                   std::string* result) {
  return OrderedCode::ReadString(src, result);
}

// Read/WriteIncreasing<uint64_t>
template <>
void OCWriteIncreasing<uint64_t>(std::string* dest, const uint64_t& val) {
  OrderedCode::WriteNumIncreasing(dest, val);
}
template <>
bool OCReadIncreasing<uint64_t>(absl::string_view* src, uint64_t* result) {
  return OrderedCode::ReadNumIncreasing(src, result);
}

enum Direction { INCREASING = 0 };

// Read/WriteIncreasing<int64_t>
template <>
void OCWriteIncreasing<int64_t>(std::string* dest, const int64_t& val) {
  OrderedCode::WriteSignedNumIncreasing(dest, val);
}
template <>
bool OCReadIncreasing<int64_t>(absl::string_view* src, int64_t* result) {
  return OrderedCode::ReadSignedNumIncreasing(src, result);
}

template <typename T>
std::string OCWrite(T val, Direction direction) {
  EXPECT_EQ(INCREASING, direction);  // DECREASING never implemented.
  std::string result;
  OCWriteIncreasing<T>(&result, val);
  return result;
}

template <typename T>
void OCWriteToString(std::string* result, T val, Direction direction) {
  EXPECT_EQ(INCREASING, direction);  // DECREASING never implemented.
  OCWriteIncreasing<T>(result, val);
}

template <typename T>
bool OCRead(absl::string_view* s, T* val, Direction direction) {
  EXPECT_EQ(INCREASING, direction);  // DECREASING never implemented.
  return OCReadIncreasing<T>(s, val);
}

// ---------------------------------------------------------------------
// Numbers

template <typename T>
static T TestRead(Direction d, const std::string& a) {
  // gracefully reject any proper prefix of an encoding
  for (size_t i = 0; i < a.size() - 1; ++i) {
    absl::string_view s(a.data(), i);
    EXPECT_TRUE(!OCRead<T>(&s, NULL, d));
    EXPECT_EQ(s, a.substr(0, i));
  }

  absl::string_view s(a);
  T v;
  EXPECT_TRUE(OCRead<T>(&s, &v, d));
  EXPECT_TRUE(s.empty());
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
  EXPECT_EQ(absl::string_view(encoded).substr(0, encoded_first_only.length()),
            encoded_first_only);
}

template <typename T>
static void TestNumbers(T multiplier) {
  for (int j = 0; j < 1; ++j) {
    const Direction d = static_cast<Direction>(j);

    // first test powers of 2 (and nearby numbers)
    for (T x = std::numeric_limits<T>().max(); x != 0; x /= 2) {
      TestWriteRead(d, multiplier * (x - 1));
      TestWriteRead(d, multiplier * x);
      if (x != std::numeric_limits<T>::max()) {
        TestWriteRead(d, multiplier * (x + 1));
      } else if (multiplier < 0 && static_cast<int64_t>(multiplier) == -1) {
        TestWriteRead(d, -x - 1);
      }
    }

    SecureRandom rnd;  // Generate 32bit pseudo-random integer.
    for (int bits = 1; bits <= std::numeric_limits<T>().digits; ++bits) {
      // test random non-negative numbers with given number of significant bits
      const uint64_t mask = (~0ULL) >> (64 - bits);
      for (int i = 0; i < 1000; i++) {
        T x = static_cast<T>((static_cast<uint64_t>(rnd()) << 32 |
                              static_cast<uint64_t>(rnd())) &
                             mask);
        TestWriteRead(d, multiplier * x);
        T y = static_cast<T>((static_cast<uint64_t>(rnd()) << 32 |
                              static_cast<uint64_t>(rnd())) &
                             mask);
        TestWriteAppends(d, multiplier * x, multiplier * y);
      }
    }
  }
}

// Return true iff 'a' is "before" 'b' according to 'direction'
static bool CompareStrings(const std::string& a,
                           const std::string& b,
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

    EXPECT_TRUE(CompareStrings(strminus1, str, d));
    EXPECT_TRUE(CompareStrings(str, strplus1, d));

    // Compare 'str' with 'laststr'.  When we approach 0, 'laststr' is
    // not necessarily before 'strminus1'.
    EXPECT_TRUE(CompareStrings(laststr, str, d));
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

    EXPECT_TRUE(CompareStrings(strminus1, str, d));
    EXPECT_TRUE(CompareStrings(str, strplus1, d));

    // Compare 'str' with 'laststr'.
    EXPECT_TRUE(CompareStrings(laststr, str, d));
    laststr = str;
  }
}

// Helper routine for testing TEST_SkipToNextSpecialByte
static size_t FindSpecial(const std::string& x) {
  const char* p = x.data();
  const char* limit = p + x.size();
  const char* result = OrderedCode::TEST_SkipToNextSpecialByte(p, limit);
  return static_cast<size_t>(result - p);
}

TEST(OrderedCode, SkipToNextSpecialByte) {
  for (size_t len = 0; len < 256; len++) {
    SecureRandom rnd;
    std::string x;
    while (x.size() < len) {
      char c = 1 + static_cast<char>(rnd.Uniform(254));
      ASSERT_NE(c, 0);
      ASSERT_NE(c, 255);
      x += c;  // No 0 bytes, no 255 bytes
    }
    EXPECT_EQ(FindSpecial(x), x.size());
    for (size_t special_pos = 0; special_pos < len; special_pos++) {
      for (int special_test = 0; special_test < 2; special_test++) {
        const char special_byte = (special_test == 0) ? 0 : '\xff';
        std::string y = x;
        y[special_pos] = special_byte;
        EXPECT_EQ(FindSpecial(y), special_pos);
        if (special_pos < 16) {
          // Add some special bytes after the one at special_pos to make sure
          // we still return the earliest special byte in the string
          for (size_t rest = special_pos + 1; rest < len; rest++) {
            if (rnd.OneIn(3)) {
              y[rest] = rnd.OneIn(2) ? 0 : '\xff';
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
          buf[start_offset + 0] = static_cast<char>(b0);
          buf[start_offset + 1] = static_cast<char>(b1);
          buf[start_offset + 2] = static_cast<char>(b2);
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

TEST(OrderedCodeUint64, EncodeDecode) {
  TestNumbers<uint64_t>(1);
}

TEST(OrderedCodeUint64, Ordering) {
  TestNumberOrdering<uint64_t>();
}

TEST(OrderedCodeInt64, EncodeDecode) {
  TestNumbers<int64_t>(1);
  TestNumbers<int64_t>(-1);
}

TEST(OrderedCodeInt64, Ordering) {
  TestNumberOrdering<int64_t>();
}

// Returns the bitwise complement of s.
static inline std::string StrNot(const std::string& s) {
  std::string result;
  for (const char c : s) result.push_back(~c);
  return result;
}

template <typename T>
static void TestInvalidEncoding(Direction d, const std::string& s) {
  absl::string_view p(s);
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

  SecureRandom rnd;

  for (int n = 2; n <= 9; ++n) {
    // The zero in non_minimal[1] is "redundant".
    std::string non_minimal =
        std::string(1, n - 1) + std::string(1, 0) + RandomString(&rnd, n - 2);
    EXPECT_EQ(static_cast<size_t>(n), non_minimal.length());

    EXPECT_NE(OCWrite<uint64_t>(0, INCREASING), non_minimal);

#if defined(NDEBUG)
    EXPECT_ANY_THROW(TestRead<uint64_t>(INCREASING, non_minimal));
#else   // defined(NDEBUG)
    absl::string_view s(non_minimal);
    EXPECT_ANY_THROW(OrderedCode::ReadNumIncreasing(&s, NULL));
#endif  // defined(NDEBUG)
  }

  for (int n = 2; n <= 10; ++n) {
    // Header with 1 sign bit and n-1 size bits.
    std::string header =
        std::string(n / 8, '\xff') + std::string(1, 0xff << (8 - (n % 8)));
    // There are more than 7 zero bits between header bits and "payload".
    std::string non_minimal =
        header +
        std::string(1,
                    static_cast<char>(rnd.Uniform(256)) & ~*header.rbegin()) +
        RandomString(&rnd, n - static_cast<int>(header.length()) - 1);
    EXPECT_EQ(static_cast<size_t>(n), non_minimal.length());

    EXPECT_NE(OCWrite<int64_t>(0, INCREASING), non_minimal);

#if defined(NDEBUG)
    EXPECT_ANY_THROW(TestRead<int64_t>(INCREASING, non_minimal));
#else   // defined(NDEBUG)
    absl::string_view s(non_minimal);
    EXPECT_ANY_THROW(OrderedCode::ReadSignedNumIncreasing(&s, NULL));
    s = non_minimal;
#endif  // defined(NDEBUG)
  }
}

// ---------------------------------------------------------------------
// Strings

TEST(OrderedCodeString, Infinity) {
  const std::string value("\xff\xff foo");
  bool is_inf;
  std::string encoding, parsed;
  absl::string_view s;

  // Check encoding/decoding of "infinity" for ascending order
  encoding.clear();
  OrderedCode::WriteInfinity(&encoding);
  encoding.push_back('a');
  s = encoding;
  EXPECT_TRUE(OrderedCode::ReadInfinity(&s));
  EXPECT_EQ(1u, s.size());
  s = encoding;
  is_inf = false;
  EXPECT_TRUE(OrderedCode::ReadStringOrInfinity(&s, NULL, &is_inf));
  EXPECT_EQ(1u, s.size());
  EXPECT_TRUE(is_inf);

  // Check ReadStringOrInfinity() can parse ordinary strings
  encoding.clear();
  OrderedCode::WriteString(&encoding, value);
  encoding.push_back('a');
  s = encoding;
  is_inf = false;
  parsed.clear();
  EXPECT_TRUE(OrderedCode::ReadStringOrInfinity(&s, &parsed, &is_inf));
  EXPECT_EQ(1u, s.size());
  EXPECT_FALSE(is_inf);
  EXPECT_EQ(value, parsed);
}

TEST(OrderedCodeString, EncodeDecode) {
  SecureRandom rnd;
  for (int i = 0; i < 1; ++i) {
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
        absl::string_view s = out;
        absl::string_view s2 = out;
        EXPECT_TRUE(OCRead<std::string>(&s, &a2, d));
        EXPECT_TRUE(OCRead<std::string>(&s2, NULL, d));
        EXPECT_EQ(s, s2);

        EXPECT_TRUE(OCRead<std::string>(&s, &b2, d));
        EXPECT_TRUE(OCRead<std::string>(&s2, NULL, d));
        EXPECT_EQ(s, s2);

        EXPECT_TRUE(!OCRead<std::string>(&s, &dummy, d));
        EXPECT_TRUE(!OCRead<std::string>(&s2, NULL, d));
        EXPECT_EQ(a, a2);
        EXPECT_EQ(b, b2);
        EXPECT_TRUE(s.empty());
        EXPECT_TRUE(s2.empty());
      }
    }
  }
}

// 'str' is a static C-style string that may contain '\0'
#define STATIC_STR(str) absl::string_view((str), sizeof(str) - 1)

static std::string EncodeStringIncreasing(absl::string_view value) {
  std::string encoded;
  OrderedCode::WriteString(&encoded, value);
  return encoded;
}

TEST(OrderedCodeString, Increasing) {
  // Here are a series of strings in non-decreasing order, including
  // consecutive strings such that the second one is equal to, a proper
  // prefix of, or has the same length as the first one.  Most also contain
  // the special escaping characters '\x00' and '\xff'.
  EXPECT_EQ(EncodeStringIncreasing(STATIC_STR("")),
            EncodeStringIncreasing(STATIC_STR("")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("")),
            EncodeStringIncreasing(STATIC_STR("\x00")));

  EXPECT_EQ(EncodeStringIncreasing(STATIC_STR("\x00")),
            EncodeStringIncreasing(STATIC_STR("\x00")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("\x00")),
            EncodeStringIncreasing(STATIC_STR("\x01")));

  ASSERT_LT(EncodeStringIncreasing(STATIC_STR("\x01")),
            EncodeStringIncreasing(STATIC_STR("a")));

  EXPECT_EQ(EncodeStringIncreasing(STATIC_STR("a")),
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

}  // namespace util
}  // namespace firestore
}  // namespace firebase
