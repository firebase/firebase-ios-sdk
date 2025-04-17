/*
 * Copyright 2025 Google LLC
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

#include <initializer_list>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/api/expressions.h"
#include "Firestore/core/src/core/expressions_eval.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/test/unit/testutil/expression_test_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"  // For Value, Bytes etc.
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using api::Expr;
using api::FunctionExpr;
using testutil::ByteLengthExpr;
using testutil::Bytes;
using testutil::CharLengthExpr;
using testutil::EndsWithExpr;
using testutil::EvaluateExpr;
using testutil::Field;
using testutil::LikeExpr;
using testutil::Map;  // Added Map helper
using testutil::RegexContainsExpr;
using testutil::RegexMatchExpr;
using testutil::Returns;
using testutil::ReturnsError;
using testutil::ReturnsNull;  // If needed for string functions
using testutil::ReverseExpr;
using testutil::SharedConstant;
using testutil::StartsWithExpr;
using testutil::StrConcatExpr;
using testutil::StrContainsExpr;
using testutil::ToLowerExpr;
using testutil::ToUpperExpr;
using testutil::TrimExpr;
using testutil::Value;

// Fixtures for different string functions
class ByteLengthTest : public ::testing::Test {};
class CharLengthTest : public ::testing::Test {};
class StrConcatTest : public ::testing::Test {};
class EndsWithTest : public ::testing::Test {};
class LikeTest : public ::testing::Test {};
class RegexContainsTest : public ::testing::Test {};
class RegexMatchTest : public ::testing::Test {};
class StartsWithTest : public ::testing::Test {};
class StrContainsTest : public ::testing::Test {};
class ToLowerTest : public ::testing::Test {};
class ToUpperTest : public ::testing::Test {};
class TrimTest : public ::testing::Test {};
class ReverseTest : public ::testing::Test {};

// --- ByteLength Tests ---
TEST_F(ByteLengthTest, EmptyString) {
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(""))),
              Returns(Value(0LL)));
}

TEST_F(ByteLengthTest, EmptyByte) {
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(Value(Bytes({}))))),
              Returns(Value(0LL)));
}

TEST_F(ByteLengthTest, NonStringOrBytesReturnsError) {
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(123LL))),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(true))),
              ReturnsError());
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(
                  SharedConstant(Value(Bytes({0x01, 0x02, 0x03}))))),
              Returns(Value(3LL)));
}

TEST_F(ByteLengthTest, HighSurrogateOnly) {
  // UTF-8 encoding of a lone high surrogate is invalid.
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(
                  u"\xED\xA0\xBC"))),  // U+D83C encoded incorrectly
              ReturnsError());         // Expect error for invalid UTF-8
}

TEST_F(ByteLengthTest, LowSurrogateOnly) {
  // UTF-8 encoding of a lone low surrogate is invalid.
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(
                  u"\xED\xBD\x93"))),  // U+DF53 encoded incorrectly
              ReturnsError());         // Expect error for invalid UTF-8
}

TEST_F(ByteLengthTest, LowAndHighSurrogateSwapped) {
  // Invalid sequence
  EXPECT_THAT(EvaluateExpr(
                  *ByteLengthExpr(SharedConstant(u"\xED\xBD\x93\xED\xA0\xBC"))),
              ReturnsError());  // Expect error for invalid UTF-8
}

TEST_F(ByteLengthTest, WrongContinuation) {
  std::vector<std::string> invalids{
      // 1. Invalid Start Byte (0xFF is not a valid start byte)
      //    UTF-8 start bytes must be in the patterns 0xxxxxxx, 110xxxxx,
      //    1110xxxx, or 11110xxx.
      //    Bytes 0xC0, 0xC1, and 0xF5 to 0xFF are always invalid.
      "Start \xFF End",

      // 2. Missing Continuation Byte(s)
      //    0xE2 requires two continuation bytes (10xxxxxx), but only one is
      //    provided before 'E'.
      "Incomplete \xE2\x82 End",  // Needs one more byte after \x82

      //    0xF0 requires three continuation bytes, but none are provided before
      //    'E'.
      "Incomplete \xF0 End",  // Needs three bytes after \xF0

      // 3. Invalid Continuation Byte
      //    0xE2 indicates a 3-byte sequence, expecting two bytes starting with
      //    10xxxxxx.
      //    However, the second byte is 0x20 (' '), which is ASCII and doesn't
      //    start with 10.
      "Bad follow byte \xE2\x82\x20 End",  // 0x20 is not 10xxxxxx

      // 4. Overlong Encoding (ASCII character '/' encoded using 2 bytes)
      //    The code point U+002F ('/') should be encoded as just 0x2F in UTF-8.
      //    Encoding it as 0xC0 0xAF is invalid (overlong). Note: 0xC0/0xC1 are
      //    always invalid starts.
      //    Let's use a different example: encoding U+00A9 (©) as 3 bytes when
      //    it should be 2.
      //    Correct: 0xC2 0xA9
      //    Invalid Overlong Example (hypothetical, often caught by decoders):
      //    Trying to encode NULL (0x00) as 0xC0 0x80
      "Overlong NULL \xC0\x80",   // Invalid way to encode U+0000
      "Overlong Slash \xC0\xAF",  // Invalid way to encode U+002F ('/')

      // 5. Sequence Decodes to Invalid Code Point (Surrogate Half)
      //    UTF-8 must not encode code points in the surrogate range U+D800 to
      //    U+DFFF.
      //    The sequence 0xED 0xA0 0x80 decodes to U+D800, which is an invalid
      //    surrogate.
      "Surrogate \xED\xA0\x80",  // Decodes to U+D800

      // 6. Sequence Decodes to Code Point > U+10FFFF
      //    Unicode code points only go up to U+10FFFF.
      //    This sequence (if interpreted loosely) might represent a value
      //    outside the valid range.
      //    For example, 0xF4 0x90 0x80 0x80 decodes to U+110000.
      "Too high \xF4\x90\x80\x80"  // Decodes to U+110000
  };

  for (const auto& invalid : invalids) {
    EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(invalid.c_str()))),
                ReturnsError());
  }
}

TEST_F(ByteLengthTest, Ascii) {
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("abc"))),
              Returns(Value(3LL)));
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("1234"))),
              Returns(Value(4LL)));
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("abc123!@"))),
              Returns(Value(8LL)));
}

TEST_F(ByteLengthTest, LargeString) {
  std::string large_a(1500, 'a');
  std::string large_ab(3000, ' ');  // Preallocate
  for (int i = 0; i < 1500; ++i) {
    large_ab[2 * i] = 'a';
    large_ab[2 * i + 1] = 'b';
  }

  // Use .c_str() for std::string variables
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(large_a.c_str()))),
              Returns(Value(1500LL)));
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(large_ab.c_str()))),
              Returns(Value(3000LL)));
}

TEST_F(ByteLengthTest, TwoBytesPerCharacter) {
  // UTF-8: é=2, ç=2, ñ=2, ö=2, ü=2 => 10 bytes
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("éçñöü"))),
              Returns(Value(10LL)));
  EXPECT_THAT(
      EvaluateExpr(*ByteLengthExpr(SharedConstant(Value(Bytes(
          {0xc3, 0xa9, 0xc3, 0xa7, 0xc3, 0xb1, 0xc3, 0xb6, 0xc3, 0xbc}))))),
      Returns(Value(10LL)));
}

TEST_F(ByteLengthTest, ThreeBytesPerCharacter) {
  // UTF-8: 你=3, 好=3, 世=3, 界=3 => 12 bytes
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("你好世界"))),
              Returns(Value(12LL)));
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(
                  Value(Bytes({0xe4, 0xbd, 0xa0, 0xe5, 0xa5, 0xbd, 0xe4, 0xb8,
                               0x96, 0xe7, 0x95, 0x8c}))))),
              Returns(Value(12LL)));
}

TEST_F(ByteLengthTest, FourBytesPerCharacter) {
  // UTF-8: 🀘=4, 🂡=4 => 8 bytes (U+1F018, U+1F0A1)
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("🀘🂡"))),
              Returns(Value(8LL)));
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant(Value(
                  Bytes({0xF0, 0x9F, 0x80, 0x98, 0xF0, 0x9F, 0x82, 0xA1}))))),
              Returns(Value(8LL)));
}

TEST_F(ByteLengthTest, MixOfDifferentEncodedLengths) {
  // a=1, é=2, 好=3, 🂡=4 => 10 bytes
  EXPECT_THAT(EvaluateExpr(*ByteLengthExpr(SharedConstant("aé好🂡"))),
              Returns(Value(10LL)));
  EXPECT_THAT(
      EvaluateExpr(*ByteLengthExpr(SharedConstant(Value(Bytes(
          {0x61, 0xc3, 0xa9, 0xe5, 0xa5, 0xbd, 0xF0, 0x9F, 0x82, 0xA1}))))),
      Returns(Value(10LL)));
}

// --- CharLength Tests ---
TEST_F(CharLengthTest, EmptyString) {
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant(""))),
              Returns(Value(0LL)));
}

TEST_F(CharLengthTest, BytesTypeReturnsError) {
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(
                  SharedConstant(Value(Bytes({'a', 'b', 'c'}))))),
              ReturnsError());
}

TEST_F(CharLengthTest, BaseCaseBmp) {
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("abc"))),
              Returns(Value(3LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("1234"))),
              Returns(Value(4LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("abc123!@"))),
              Returns(Value(8LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("你好世界"))),
              Returns(Value(4LL)));  // Each char is 1 code point
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("cafétéria"))),
              Returns(Value(9LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("абвгд"))),
              Returns(Value(5LL)));
  EXPECT_THAT(
      EvaluateExpr(*CharLengthExpr(SharedConstant("¡Hola! ¿Cómo estás?"))),
      Returns(Value(19LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("☺"))),  // U+263A
              Returns(Value(1LL)));
}

TEST_F(CharLengthTest, Spaces) {
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant(""))),
              Returns(Value(0LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant(" "))),
              Returns(Value(1LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("  "))),
              Returns(Value(2LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("a b"))),
              Returns(Value(3LL)));
}

TEST_F(CharLengthTest, SpecialCharacters) {
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("\n"))),
              Returns(Value(1LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("\t"))),
              Returns(Value(1LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("\\"))),
              Returns(Value(1LL)));
}

TEST_F(CharLengthTest, BmpSmpMix) {
  // Hello = 5, Smiling Face Emoji (U+1F60A) = 1 => 6 code points
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("Hello😊"))),
              Returns(Value(6LL)));
}

TEST_F(CharLengthTest, Smp) {
  // Strawberry (U+1F353) = 1, Peach (U+1F351) = 1 => 2 code points
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant("🍓🍑"))),
              Returns(Value(2LL)));
}

// Note: C++ char_length likely counts code points correctly, unlike JS which
// might count UTF-16 code units for lone surrogates. Assuming C++ counts code
// points.
TEST_F(CharLengthTest, HighSurrogateOnly) {
  // Lone high surrogate U+D83C is 1 code point (though invalid sequence)
  EXPECT_THAT(
      EvaluateExpr(
          *CharLengthExpr(SharedConstant("\xED\xA0\xBC"))),  // Invalid UTF-8
      ReturnsError());  // Expect error if implementation validates UTF-8
  // Returns(Value(1LL))); // Or returns 1 if it counts invalid points
}

TEST_F(CharLengthTest, LowSurrogateOnly) {
  // Lone low surrogate U+DF53 is 1 code point (though invalid sequence)
  EXPECT_THAT(
      EvaluateExpr(
          *CharLengthExpr(SharedConstant("\xED\xBD\x93"))),  // Invalid UTF-8
      ReturnsError());  // Expect error if implementation validates UTF-8
  // Returns(Value(1LL))); // Or returns 1 if it counts invalid points
}

TEST_F(CharLengthTest, LowAndHighSurrogateSwapped) {
  // Swapped surrogates are 2 code points (though invalid sequence)
  EXPECT_THAT(
      EvaluateExpr(*CharLengthExpr(
          SharedConstant("\xED\xBD\x93\xED\xA0\xBC"))),  // Invalid UTF-8
      ReturnsError());  // Expect error if implementation validates UTF-8
  // Returns(Value(2LL))); // Or returns 2 if it counts invalid points
}

TEST_F(CharLengthTest, LargeString) {
  std::string large_a(1500, 'a');
  std::string large_ab(3000, ' ');  // Preallocate
  for (int i = 0; i < 1500; ++i) {
    large_ab[2 * i] = 'a';
    large_ab[2 * i + 1] = 'b';
  }

  // Use .c_str() for std::string variables
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant(large_a.c_str()))),
              Returns(Value(1500LL)));
  EXPECT_THAT(EvaluateExpr(*CharLengthExpr(SharedConstant(large_ab.c_str()))),
              Returns(Value(3000LL)));
}

// --- StrConcat Tests ---
TEST_F(StrConcatTest, MultipleStringChildrenReturnsCombination) {
  EXPECT_THAT(
      EvaluateExpr(*StrConcatExpr(
          {SharedConstant("foo"), SharedConstant(" "), SharedConstant("bar")})),
      Returns(Value("foo bar")));
}

TEST_F(StrConcatTest, MultipleNonStringChildrenReturnsError) {
  EXPECT_THAT(
      EvaluateExpr(*StrConcatExpr({SharedConstant("foo"), SharedConstant(42LL),
                                   SharedConstant("bar")})),
      ReturnsError());
}

TEST_F(StrConcatTest, MultipleCalls) {
  auto func = StrConcatExpr(
      {SharedConstant("foo"), SharedConstant(" "), SharedConstant("bar")});
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value("foo bar")));
  EXPECT_THAT(EvaluateExpr(*func),
              Returns(Value("foo bar")));  // Ensure expression is reusable
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value("foo bar")));
}

TEST_F(StrConcatTest, LargeNumberOfInputs) {
  std::vector<std::shared_ptr<Expr>> args;
  std::string expected_result = "";
  args.reserve(500);
  for (int i = 0; i < 500; ++i) {
    args.push_back(SharedConstant("a"));
    expected_result += "a";
  }
  // Need to construct FunctionExpr with vector directly
  auto func = StrConcatExpr(std::move(args));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(expected_result)));
}

TEST_F(StrConcatTest, LargeStrings) {
  std::string a500(500, 'a');
  std::string b500(500, 'b');
  std::string c500(500, 'c');
  // Use .c_str() for std::string variables
  auto func =
      StrConcatExpr({SharedConstant(a500.c_str()), SharedConstant(b500.c_str()),
                     SharedConstant(c500.c_str())});
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(a500 + b500 + c500)));
}

// --- EndsWith Tests ---
TEST_F(EndsWithTest, GetNonStringValueIsError) {
  EXPECT_THAT(EvaluateExpr(*EndsWithExpr(SharedConstant(42LL),
                                         SharedConstant("search"))),
              ReturnsError());
}

TEST_F(EndsWithTest, GetNonStringSuffixIsError) {
  EXPECT_THAT(EvaluateExpr(*EndsWithExpr(SharedConstant("search"),
                                         SharedConstant(42LL))),
              ReturnsError());
}

TEST_F(EndsWithTest, GetEmptyInputsReturnsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*EndsWithExpr(SharedConstant(""), SharedConstant(""))),
      Returns(Value(true)));
}

TEST_F(EndsWithTest, GetEmptyValueReturnsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*EndsWithExpr(SharedConstant(""), SharedConstant("v"))),
      Returns(Value(false)));
}

TEST_F(EndsWithTest, GetEmptySuffixReturnsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*EndsWithExpr(SharedConstant("value"), SharedConstant(""))),
      Returns(Value(true)));
}

TEST_F(EndsWithTest, GetReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*EndsWithExpr(SharedConstant("search"),
                                         SharedConstant("rch"))),
              Returns(Value(true)));
}

TEST_F(EndsWithTest, GetReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*EndsWithExpr(SharedConstant("search"),
                                         SharedConstant("rcH"))),
              Returns(Value(false)));  // Case-sensitive
}

TEST_F(EndsWithTest, GetLargeSuffixReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*EndsWithExpr(SharedConstant("val"),
                                         SharedConstant("a very long suffix"))),
              Returns(Value(false)));
}

// --- Like Tests ---
TEST_F(LikeTest, GetNonStringLikeIsError) {
  EXPECT_THAT(
      EvaluateExpr(*LikeExpr(SharedConstant(42LL), SharedConstant("search"))),
      ReturnsError());
}

TEST_F(LikeTest, GetNonStringValueIsError) {
  EXPECT_THAT(
      EvaluateExpr(*LikeExpr(SharedConstant("ear"), SharedConstant(42LL))),
      ReturnsError());
}

TEST_F(LikeTest, GetStaticLike) {
  auto func = LikeExpr(SharedConstant("yummy food"), SharedConstant("%food"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));  // Reusable
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));
}

TEST_F(LikeTest, GetEmptySearchString) {
  auto func = LikeExpr(SharedConstant(""), SharedConstant("%hi%"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(false)));
}

TEST_F(LikeTest, GetEmptyLike) {
  auto func = LikeExpr(SharedConstant("yummy food"), SharedConstant(""));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(false)));
}

TEST_F(LikeTest, GetEscapedLike) {
  auto func =
      LikeExpr(SharedConstant("yummy food??"), SharedConstant("%food??"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));
}

TEST_F(LikeTest, GetDynamicLike) {
  // Construct FunctionExpr directly for mixed types
  auto func = std::make_shared<FunctionExpr>(
      "like",
      std::vector<std::shared_ptr<Expr>>{
          SharedConstant("yummy food"), std::make_shared<api::Field>("regex")});
  EXPECT_THAT(EvaluateExpr(*func, testutil::Doc("coll/doc1", 1,
                                                Map("regex", Value("yummy%")))),
              Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(*func, testutil::Doc("coll/doc2", 1,
                                                Map("regex", Value("food%")))),
              Returns(Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*func, testutil::Doc("coll/doc3", 1,
                                        Map("regex", Value("yummy_food")))),
      Returns(Value(true)));
}

// --- RegexContains Tests ---
TEST_F(RegexContainsTest, GetNonStringRegexIsError) {
  EXPECT_THAT(EvaluateExpr(*RegexContainsExpr(SharedConstant(42LL),
                                              SharedConstant("search"))),
              ReturnsError());
}

TEST_F(RegexContainsTest, GetNonStringValueIsError) {
  EXPECT_THAT(EvaluateExpr(*RegexContainsExpr(SharedConstant("ear"),
                                              SharedConstant(42LL))),
              ReturnsError());
}

TEST_F(RegexContainsTest, GetInvalidRegexIsError) {
  // Assuming C++ uses RE2 or similar, backreferences might be
  // invalid/unsupported
  auto func =
      RegexContainsExpr(SharedConstant("abcabc"), SharedConstant("(abc)\\1"));
  EXPECT_THAT(EvaluateExpr(*func), ReturnsError());
}

TEST_F(RegexContainsTest, GetStaticRegex) {
  auto func =
      RegexContainsExpr(SharedConstant("yummy food"), SharedConstant(".*oo.*"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));
}

TEST_F(RegexContainsTest, GetSubStringLiteral) {
  auto func = RegexContainsExpr(SharedConstant("yummy good food"),
                                SharedConstant("good"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));
}

TEST_F(RegexContainsTest, GetSubStringRegex) {
  auto func = RegexContainsExpr(SharedConstant("yummy good food"),
                                SharedConstant("go*d"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(true)));
}

TEST_F(RegexContainsTest, GetDynamicRegex) {
  // Construct FunctionExpr directly for mixed types
  auto func = std::make_shared<FunctionExpr>(
      "regex_contains",
      std::vector<std::shared_ptr<Expr>>{
          SharedConstant("yummy food"), std::make_shared<api::Field>("regex")});
  EXPECT_THAT(
      EvaluateExpr(*func, testutil::Doc("coll/doc1", 1,
                                        Map("regex", Value("^yummy.*")))),
      Returns(Value(true)));
  EXPECT_THAT(
      EvaluateExpr(
          *func, testutil::Doc("coll/doc2", 1, Map("regex", Value("fooood$")))),
      Returns(Value(false)));
  EXPECT_THAT(EvaluateExpr(*func, testutil::Doc("coll/doc3", 1,
                                                Map("regex", Value(".*")))),
              Returns(Value(true)));
}

// --- RegexMatch Tests ---
TEST_F(RegexMatchTest, GetNonStringRegexIsError) {
  EXPECT_THAT(EvaluateExpr(*RegexMatchExpr(SharedConstant(42LL),
                                           SharedConstant("search"))),
              ReturnsError());
}

TEST_F(RegexMatchTest, GetNonStringValueIsError) {
  EXPECT_THAT(EvaluateExpr(
                  *RegexMatchExpr(SharedConstant("ear"), SharedConstant(42LL))),
              ReturnsError());
}

TEST_F(RegexMatchTest, GetInvalidRegexIsError) {
  // Assuming C++ uses RE2 or similar, backreferences might be
  // invalid/unsupported
  auto func =
      RegexMatchExpr(SharedConstant("abcabc"), SharedConstant("(abc)\\1"));
  EXPECT_THAT(EvaluateExpr(*func), ReturnsError());
}

TEST_F(RegexMatchTest, GetStaticRegex) {
  auto func =
      RegexMatchExpr(SharedConstant("yummy food"), SharedConstant(".*oo.*"));
  EXPECT_THAT(EvaluateExpr(*func),
              Returns(Value(true)));  // Matches because .* matches whole string
}

TEST_F(RegexMatchTest, GetSubStringLiteral) {
  // regex_match requires full match
  auto func =
      RegexMatchExpr(SharedConstant("yummy good food"), SharedConstant("good"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(false)));
}

TEST_F(RegexMatchTest, GetSubStringRegex) {
  // regex_match requires full match
  auto func =
      RegexMatchExpr(SharedConstant("yummy good food"), SharedConstant("go*d"));
  EXPECT_THAT(EvaluateExpr(*func), Returns(Value(false)));
}

TEST_F(RegexMatchTest, GetDynamicRegex) {
  // Construct FunctionExpr directly for mixed types
  auto func = std::make_shared<FunctionExpr>(
      "regex_match",
      std::vector<std::shared_ptr<Expr>>{
          SharedConstant("yummy food"), std::make_shared<api::Field>("regex")});
  EXPECT_THAT(
      EvaluateExpr(*func, testutil::Doc("coll/doc1", 1,
                                        Map("regex", Value("^yummy.*")))),
      Returns(Value(true)));  // Matches full string
  EXPECT_THAT(
      EvaluateExpr(
          *func, testutil::Doc("coll/doc2", 1, Map("regex", Value("fooood$")))),
      Returns(Value(false)));
  EXPECT_THAT(EvaluateExpr(*func, testutil::Doc("coll/doc3", 1,
                                                Map("regex", Value(".*")))),
              Returns(Value(true)));  // Matches full string
  EXPECT_THAT(EvaluateExpr(*func, testutil::Doc("coll/doc4", 1,
                                                Map("regex", Value("yummy")))),
              Returns(Value(false)));  // Does not match full string
}

// --- StartsWith Tests ---
TEST_F(StartsWithTest, GetNonStringValueIsError) {
  EXPECT_THAT(EvaluateExpr(*StartsWithExpr(SharedConstant(42LL),
                                           SharedConstant("search"))),
              ReturnsError());
}

TEST_F(StartsWithTest, GetNonStringPrefixIsError) {
  EXPECT_THAT(EvaluateExpr(*StartsWithExpr(SharedConstant("search"),
                                           SharedConstant(42LL))),
              ReturnsError());
}

TEST_F(StartsWithTest, GetEmptyInputsReturnsTrue) {
  EXPECT_THAT(
      EvaluateExpr(*StartsWithExpr(SharedConstant(""), SharedConstant(""))),
      Returns(Value(true)));
}

TEST_F(StartsWithTest, GetEmptyValueReturnsFalse) {
  EXPECT_THAT(
      EvaluateExpr(*StartsWithExpr(SharedConstant(""), SharedConstant("v"))),
      Returns(Value(false)));
}

TEST_F(StartsWithTest, GetEmptyPrefixReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(
                  *StartsWithExpr(SharedConstant("value"), SharedConstant(""))),
              Returns(Value(true)));
}

TEST_F(StartsWithTest, GetReturnsTrue) {
  EXPECT_THAT(EvaluateExpr(*StartsWithExpr(SharedConstant("search"),
                                           SharedConstant("sea"))),
              Returns(Value(true)));
}

TEST_F(StartsWithTest, GetReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*StartsWithExpr(SharedConstant("search"),
                                           SharedConstant("Sea"))),
              Returns(Value(false)));  // Case-sensitive
}

TEST_F(StartsWithTest, GetLargePrefixReturnsFalse) {
  EXPECT_THAT(EvaluateExpr(*StartsWithExpr(
                  SharedConstant("val"), SharedConstant("a very long prefix"))),
              Returns(Value(false)));
}

// --- StrContains Tests ---
TEST_F(StrContainsTest, ValueNonStringIsError) {
  EXPECT_THAT(EvaluateExpr(*StrContainsExpr(SharedConstant(42LL),
                                            SharedConstant("value"))),
              ReturnsError());
}

TEST_F(StrContainsTest, SubStringNonStringIsError) {
  EXPECT_THAT(EvaluateExpr(*StrContainsExpr(SharedConstant("search space"),
                                            SharedConstant(42LL))),
              ReturnsError());
}

TEST_F(StrContainsTest, ExecuteTrue) {
  EXPECT_THAT(EvaluateExpr(
                  *StrContainsExpr(SharedConstant("abc"), SharedConstant("c"))),
              Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(*StrContainsExpr(SharedConstant("abc"),
                                            SharedConstant("bc"))),
              Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(*StrContainsExpr(SharedConstant("abc"),
                                            SharedConstant("abc"))),
              Returns(Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*StrContainsExpr(SharedConstant("abc"), SharedConstant(""))),
      Returns(Value(true)));
  EXPECT_THAT(
      EvaluateExpr(*StrContainsExpr(SharedConstant(""), SharedConstant(""))),
      Returns(Value(true)));
  EXPECT_THAT(EvaluateExpr(
                  *StrContainsExpr(SharedConstant("☃☃☃"), SharedConstant("☃"))),
              Returns(Value(true)));
}

TEST_F(StrContainsTest, ExecuteFalse) {
  EXPECT_THAT(EvaluateExpr(*StrContainsExpr(SharedConstant("abc"),
                                            SharedConstant("abcd"))),
              Returns(Value(false)));
  EXPECT_THAT(EvaluateExpr(
                  *StrContainsExpr(SharedConstant("abc"), SharedConstant("d"))),
              Returns(Value(false)));
  EXPECT_THAT(
      EvaluateExpr(*StrContainsExpr(SharedConstant(""), SharedConstant("a"))),
      Returns(Value(false)));
  EXPECT_THAT(EvaluateExpr(*StrContainsExpr(SharedConstant(""),
                                            SharedConstant("abcde"))),
              Returns(Value(false)));
}

// --- ToLower Tests ---
TEST_F(ToLowerTest, Basic) {
  EXPECT_THAT(EvaluateExpr(*ToLowerExpr(SharedConstant("FOO Bar"))),
              Returns(Value("foo bar")));
}

TEST_F(ToLowerTest, Empty) {
  EXPECT_THAT(EvaluateExpr(*ToLowerExpr(SharedConstant(""))),
              Returns(Value("")));
}

TEST_F(ToLowerTest, NonString) {
  EXPECT_THAT(EvaluateExpr(*ToLowerExpr(SharedConstant(123LL))),
              ReturnsError());
}

TEST_F(ToLowerTest, Null) {
  EXPECT_THAT(EvaluateExpr(*ToLowerExpr(SharedConstant(nullptr))),
              ReturnsNull());
}

// --- ToUpper Tests ---
TEST_F(ToUpperTest, Basic) {
  EXPECT_THAT(EvaluateExpr(*ToUpperExpr(SharedConstant("foo Bar"))),
              Returns(Value("FOO BAR")));
}

TEST_F(ToUpperTest, Empty) {
  EXPECT_THAT(EvaluateExpr(*ToUpperExpr(SharedConstant(""))),
              Returns(Value("")));
}

TEST_F(ToUpperTest, NonString) {
  EXPECT_THAT(EvaluateExpr(*ToUpperExpr(SharedConstant(123LL))),
              ReturnsError());
}

TEST_F(ToUpperTest, Null) {
  EXPECT_THAT(EvaluateExpr(*ToUpperExpr(SharedConstant(nullptr))),
              ReturnsNull());
}

// --- Trim Tests ---
TEST_F(TrimTest, Basic) {
  EXPECT_THAT(EvaluateExpr(*TrimExpr(SharedConstant("  foo bar  "))),
              Returns(Value("foo bar")));
}

TEST_F(TrimTest, NoTrimNeeded) {
  EXPECT_THAT(EvaluateExpr(*TrimExpr(SharedConstant("foo bar"))),
              Returns(Value("foo bar")));
}

TEST_F(TrimTest, OnlyWhitespace) {
  EXPECT_THAT(EvaluateExpr(*TrimExpr(SharedConstant("   \t\n  "))),
              Returns(Value("")));
}

TEST_F(TrimTest, Empty) {
  EXPECT_THAT(EvaluateExpr(*TrimExpr(SharedConstant(""))), Returns(Value("")));
}

TEST_F(TrimTest, NonString) {
  EXPECT_THAT(EvaluateExpr(*TrimExpr(SharedConstant(123LL))), ReturnsError());
}

TEST_F(TrimTest, Null) {
  EXPECT_THAT(EvaluateExpr(*TrimExpr(SharedConstant(nullptr))), ReturnsNull());
}

// --- Reverse Tests ---
TEST_F(ReverseTest, Basic) {
  EXPECT_THAT(EvaluateExpr(*ReverseExpr(SharedConstant("abc"))),
              Returns(Value("cba")));
}

TEST_F(ReverseTest, Empty) {
  EXPECT_THAT(EvaluateExpr(*ReverseExpr(SharedConstant(""))),
              Returns(Value("")));
}

TEST_F(ReverseTest, Unicode) {
  EXPECT_THAT(EvaluateExpr(*ReverseExpr(SharedConstant("aé好🂡"))),
              Returns(Value("🂡好éa")));
}

TEST_F(ReverseTest, NonString) {
  EXPECT_THAT(EvaluateExpr(*ReverseExpr(SharedConstant(123LL))),
              ReturnsError());
}

TEST_F(ReverseTest, Null) {
  EXPECT_THAT(EvaluateExpr(*ReverseExpr(SharedConstant(nullptr))),
              ReturnsNull());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
