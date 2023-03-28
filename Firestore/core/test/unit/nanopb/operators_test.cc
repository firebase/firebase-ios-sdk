/*
 * Copyright 2023 Google LLC
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

#include "Firestore/core/src/nanopb/operators.h"

#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace {

using nanopb::MakeBytesArray;
using nanopb::Message;

////////////////////////////////////////////////////////////////////////////////
// Tests for operator==() for google_firestore_v1_BitSequence
////////////////////////////////////////////////////////////////////////////////

class NanopbOperatorsTest_BitSequence : public ::testing::Test {
 public:
  // Stores the `padding` and `bitmap` of a `google_firestore_v1_BitSequence`
  // proto, and enables creating `Message` objects from them.
  class ProtoFieldValues {
   public:
    ProtoFieldValues(int32_t padding,
                     const absl::optional<std::vector<uint8_t>>& bitmap)
        : padding_(padding), bitmap_(bitmap) {
    }

    ProtoFieldValues(int32_t padding, const std::vector<uint8_t>& bitmap)
        : ProtoFieldValues(padding,
                           absl::optional<std::vector<uint8_t>>(bitmap)) {
    }

    Message<google_firestore_v1_BitSequence> CreateProto() const {
      Message<google_firestore_v1_BitSequence> proto;
      proto->padding = padding_;
      if (!bitmap_.has_value()) {
        proto->bitmap = nullptr;
      } else {
        proto->bitmap = MakeBytesArray(bitmap_.value());
      }
      return proto;
    }

   private:
    int32_t padding_;
    absl::optional<std::vector<uint8_t>> bitmap_;
  };

 protected:
  static void TestOperatorEquals(bool expected_result,
                                 ProtoFieldValues lhs,
                                 ProtoFieldValues rhs) {
    const Message<google_firestore_v1_BitSequence> message1 = lhs.CreateProto();
    const Message<google_firestore_v1_BitSequence> message2 = rhs.CreateProto();
    const google_firestore_v1_BitSequence& proto1 = *message1;
    const google_firestore_v1_BitSequence& proto2 = *message2;
    EXPECT_EQ(proto1 == proto2, expected_result);
    EXPECT_NE(proto1 != proto2, expected_result);
  }
};

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnTrueIfBothMessagesHaveSamePaddingAndNullBitmap) {
  TestOperatorEquals(true, {789, absl::nullopt}, {789, absl::nullopt});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnTrueIfBothMessagesHaveSamePaddingAndBitmap) {
  TestOperatorEquals(true, {789, {1, 2, 3, 4}}, {789, {1, 2, 3, 4}});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseIfDifferentPadding) {
  TestOperatorEquals(false, {789, absl::nullopt}, {987, absl::nullopt});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseIfDifferentBitmapLength) {
  TestOperatorEquals(false, {789, {1, 2, 3, 4, 5}}, {789, {1, 2, 3}});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseIfSameBitmapLengthButDifferentValues) {
  TestOperatorEquals(false, {789, {1, 2, 3, 4}}, {789, {4, 3, 2, 1}});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseIfArg1HasNullBitmapAndArg2HasNonNullBitmap) {
  TestOperatorEquals(false, {789, absl::nullopt}, {789, {4, 3, 2, 1}});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseIfArg1HasNonNullBitmapAndArg2HasNullBitmap) {
  TestOperatorEquals(false, {789, {4, 3, 2, 1}}, {789, absl::nullopt});
}

}  //  namespace
}  //  namespace firestore
}  //  namespace firebase
