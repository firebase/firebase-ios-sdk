/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/test/unit/util/byte_stream_test.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

uint64_t kMaxIterations = 10000 * 10000;

std::string LargeString() {
  std::string source;
  for (int i = 0; i < 10000; ++i) {
    source +=
        "{키스의 고유조건은 입술끼리 만나야 하고 특별한 기술은 필요치 "
        "않다}"

        "{သီဟိုဠ်မှ ဉာဏ်ကြီးရှင်သည် အာယုဝဍ္ဎနဆေးညွှန်းစာကို "
        "ဇလွန်ဈေးဘေးဗာဒံပင်ထက် အဓိဋ္ဌာန်လျက် "
        "ဂဃနဏဖတ်ခဲ့သည်။เป็นมนุษย์สุดประเสริฐเลิศคุณค่า}"

        "{กว่าบรรดาฝูงสัตว์เดรัจฉาน จงฝ่าฟันพัฒนาวิชาการ อย่าล้า"
        "งผลาญฤๅเข่นฆ่าบีฑาใคร ไม่ถือโทษโกรธแช่งซัดฮึดฮัดด่า "
        "หัดอภัยเหมือนกีฬาอัชฌาสัย ปฏิบัติประพฤติกฎกำหนดใจ "
        "พูดจาให้จ๊ะ ๆ จ๋า ๆ น่าฟังเอยฯ}";
  }
  return source;
}

TEST_P(ByteStreamTest, ReadsStringStream) {
  auto stream = stream_factory_->CreateByteStream("ok");

  auto result = stream->ReadUntil('o', 10);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_FALSE(result.eof());

  result = stream->ReadUntil('k', 10);
  EXPECT_EQ(result.ValueOrDie(), "o");
  EXPECT_FALSE(result.eof());

  result = stream->Read(10);
  EXPECT_EQ(result.ValueOrDie(), "k");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsEmptyStringStream) {
  auto stream = stream_factory_->CreateByteStream("");

  auto result = stream->ReadUntil('o', 10);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_TRUE(result.eof());

  result = stream->Read(10);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsEdgeCaseSizes) {
  {
    auto stream = stream_factory_->CreateByteStream("0123456");
    auto result = stream->Read(6);
    EXPECT_EQ(result.ValueOrDie(), "012345");
    EXPECT_FALSE(result.eof());
  }
  {
    auto stream = stream_factory_->CreateByteStream("0123456");
    auto result = stream->Read(7);
    EXPECT_EQ(result.ValueOrDie(), "0123456");
    EXPECT_TRUE(result.eof());
  }
  {
    auto stream = stream_factory_->CreateByteStream("0123456");
    auto result = stream->Read(8);
    EXPECT_EQ(result.ValueOrDie(), "0123456");
    EXPECT_TRUE(result.eof());
  }
  {
    auto stream = stream_factory_->CreateByteStream("0123456");
    auto result = stream->ReadUntil('a', 6);
    EXPECT_EQ(result.ValueOrDie(), "012345");
    EXPECT_FALSE(result.eof());
  }
  {
    auto stream = stream_factory_->CreateByteStream("0123456");
    auto result = stream->ReadUntil('a', 7);
    EXPECT_EQ(result.ValueOrDie(), "0123456");
    EXPECT_TRUE(result.eof());
  }
  {
    auto stream = stream_factory_->CreateByteStream("0123456");
    auto result = stream->ReadUntil('a', 8);
    EXPECT_EQ(result.ValueOrDie(), "0123456");
    EXPECT_TRUE(result.eof());
  }
}

TEST_P(ByteStreamTest, ReadsZeroSizes) {
  auto stream = stream_factory_->CreateByteStream("0123456");
  auto result = stream->Read(0);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_FALSE(result.eof());

  result = stream->ReadUntil('a', 0);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_FALSE(result.eof());
}

TEST_P(ByteStreamTest, ReadsEmptyStrings) {
  {
    auto stream = stream_factory_->CreateByteStream("");
    auto result = stream->Read(0);
    EXPECT_EQ(result.ValueOrDie(), "");
    EXPECT_TRUE(result.eof());
  }
  {
    auto stream = stream_factory_->CreateByteStream("");
    auto result = stream->Read(10000);
    EXPECT_EQ(result.ValueOrDie(), "");
    EXPECT_TRUE(result.eof());
  }
}

TEST_P(ByteStreamTest, ReadUntilReadsStringsWithoutDelim) {
  auto stream = stream_factory_->CreateByteStream("aaabbbccc");
  auto result = stream->ReadUntil('1', 1000);
  EXPECT_EQ(result.ValueOrDie(), "aaabbbccc");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadUntilReadsDelimString) {
  auto stream = stream_factory_->CreateByteStream("{{{{");

  auto result = stream->ReadUntil('{', 10);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_FALSE(result.eof());

  // Repeat the read
  result = stream->ReadUntil('{', 10);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_FALSE(result.eof());
}

TEST_P(ByteStreamTest, ReadUntilReadsStringWithoutDelim) {
  auto stream = stream_factory_->CreateByteStream("{{{{");

  auto result = stream->ReadUntil('}', 10);
  EXPECT_EQ(result.ValueOrDie(), "{{{{");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsNullCharacter) {
  // Using explicit string(char*, size) constructor to include \0
  auto stream =
      stream_factory_->CreateByteStream(std::string("10{conten\0t}5{\0}", 16));

  auto result = stream->ReadUntil('{', 10);
  EXPECT_EQ(result.ValueOrDie(), "10");
  EXPECT_FALSE(result.eof());

  result = stream->ReadUntil('\0', 10);
  EXPECT_EQ(result.ValueOrDie(), "{conten");

  result = stream->Read(3);
  EXPECT_EQ(result.ValueOrDie(), std::string("\0t}", 3));
  EXPECT_FALSE(result.eof());

  result = stream->ReadUntil('}', 10);
  EXPECT_EQ(result.ValueOrDie(), std::string("5{\0", 3));
  EXPECT_FALSE(result.eof());

  result = stream->Read(10);
  EXPECT_EQ(result.ValueOrDie(), "}");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsFullStringWithNullCharacter) {
  // Using explicit string(char*, size) constructor to include \0
  std::string data("10{conten\0t}5{\0}", 16);
  auto stream = stream_factory_->CreateByteStream(data);

  auto result = stream->Read(100);
  EXPECT_EQ(result.ValueOrDie(), data);
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsNonAsciiCharacter) {
  auto stream = stream_factory_->CreateByteStream("恭禧发财");

  // \xE7 is the first char of "禧发财", and it is not a byte in "恭"
  auto result = stream->ReadUntil('\xE7', 10);
  EXPECT_EQ(result.ValueOrDie(), "恭");
  EXPECT_FALSE(result.eof());

  result = stream->Read(10);
  EXPECT_EQ(result.ValueOrDie(), "禧发财");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsLargeStream) {
  auto source = LargeString();
  auto stream = stream_factory_->CreateByteStream(source);
  std::string actual;
  uint64_t i = 0;
  for (; i < kMaxIterations; ++i) {
    auto result = stream->Read(10);
    actual.append(result.ValueOrDie());
    if (result.eof()) {
      break;
    }
  }
  EXPECT_LE(i, kMaxIterations);
  EXPECT_EQ(actual, source);
}

TEST_P(ByteStreamTest, ReadUntilReadsLargeStream) {
  auto source = LargeString();
  auto stream = stream_factory_->CreateByteStream(source);
  std::string actual;
  uint64_t i = 0;
  for (; i < kMaxIterations; ++i) {
    char delim = i % 2 ? '}' : '{';
    auto result = stream->ReadUntil(delim, 1000);
    actual.append(result.ValueOrDie());
    if (result.eof()) {
      break;
    }
  }
  EXPECT_LE(i, kMaxIterations);
  EXPECT_EQ(actual, source);
}

// This is a test designed for the apple implementation's internal buffer usage.
// It deliberately fills the internal buffer with ReadsUntil, then uses Read to
// read from buffer, without IO.
TEST_P(ByteStreamTest, ReadsFromInternalBuffer_AppleImpl) {
  auto stream = stream_factory_->CreateByteStream("0123456789");
  // Reads the entire stream into internal buffer, but returns "".
  auto result = stream->ReadUntil('0', 100);
  EXPECT_EQ(result.ValueOrDie(), "");
  EXPECT_FALSE(result.eof());

  // Internal buffer size > requested read
  result = stream->Read(5);
  EXPECT_EQ(result.ValueOrDie(), "01234");
  EXPECT_FALSE(result.eof());

  // Internal buffer size == requested read
  result = stream->Read(5);
  EXPECT_EQ(result.ValueOrDie(), "56789");
  EXPECT_TRUE(result.eof());
}

}  // namespace
}  // namespace util
}  // namespace firestore
}  // namespace firebase
