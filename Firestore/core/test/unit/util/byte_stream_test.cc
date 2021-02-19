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

TEST_P(ByteStreamTest, ReadsStringStream) {
  auto stream = stream_factory_->CreateByteStream("ok");

  auto result = stream->ReadUntil('o', 10);
  EXPECT_EQ(result.result().ValueOrDie(), "");
  EXPECT_FALSE(result.eof());

  result = stream->ReadUntil('k', 10);
  EXPECT_EQ(result.result().ValueOrDie(), "o");
  EXPECT_FALSE(result.eof());

  result = stream->Read(10);
  EXPECT_EQ(result.result().ValueOrDie(), "k");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsNonAsciiCharacter) {
  auto stream = stream_factory_->CreateByteStream("恭禧发财");

  // \xE7 is the first char of "禧发财", and it is not a byte in "恭"
  auto result = stream->ReadUntil('\xE7', 10);
  EXPECT_EQ(result.result().ValueOrDie(), "恭");
  EXPECT_FALSE(result.eof());

  result = stream->Read(10);
  EXPECT_EQ(result.result().ValueOrDie(), "禧发财");
  EXPECT_TRUE(result.eof());
}

TEST_P(ByteStreamTest, ReadsLargeStream) {
  std::string source;
  for (int i = 0; i < 10000; ++i) {
    source +=
        "{키스의 고유조건은 입술끼리 만나야 하고 특별한 기술은 필요치 "
        "않다}{သီဟိုဠ်မှ ဉာဏ်ကြီးရှင်သည် အာယုဝဍ္ဎနဆေးညွှန်းစာကို ဇလွန်ဈေးဘေးဗာဒံပင်ထက် အဓိဋ္ဌာန်လျက် "
        "ဂဃနဏဖတ်ခဲ့သည်။เป็นมนุษย์สุดประเสริฐเลิศคุณค่า}{กว่าบรรดาฝูงสัตว์เดรัจฉาน "
        "จงฝ่าฟันพัฒนาวิชาการ อย่าล้างผลาญฤๅเข่นฆ่าบีฑาใคร ไม่ถือโทษโกรธแช่งซัดฮึดฮัดด่า "
        "หัดอภัยเหมือนกีฬาอัชฌาสัย ปฏิบัติประพฤติกฎกำหนดใจ พูดจาให้จ๊ะ ๆ จ๋า ๆ น่าฟังเอยฯ}";
  }

  // Read()
  {
    auto stream = stream_factory_->CreateByteStream(source);
    std::string actual;
    while (true) {
      auto result = stream->Read(10);
      actual.append(result.result().ValueOrDie());
      if (result.eof()) {
        break;
      }
    }
    EXPECT_EQ(actual, source);
  }

  // ReadUntil
  {
    auto stream = stream_factory_->CreateByteStream(source);
    std::string actual;
    std::string chars = "}{";
    int i = 0;
    while (true) {
      auto result = stream->ReadUntil(chars.at((i++) % 2), 1000);
      actual.append(result.result().ValueOrDie());
      if (result.eof()) {
        break;
      }
    }
    EXPECT_EQ(actual, source);
  }
}

}  // namespace
}  // namespace util
}  // namespace firestore
}  // namespace firebase
