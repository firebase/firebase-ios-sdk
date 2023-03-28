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
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace {

using nanopb::MakeBytesArray;
using nanopb::Message;

TEST(
    OperatorsTest,
    BitSequenceOperatorEqualsShouldReturnTrueIfBothArgsHaveSamePaddingAndNullBitmap) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 789;
  bit_sequence1->bitmap = nullptr;
  bit_sequence2->bitmap = nullptr;

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_TRUE(proto1 == proto2);
  EXPECT_FALSE(proto1 != proto2);
}

TEST(
    OperatorsTest,
    BitSequenceOperatorEqualsShouldReturnTrueIfBothArgsHaveSamePaddingAndBitmap) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 789;
  bit_sequence1->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3, 4});
  bit_sequence2->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3, 4});

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_TRUE(proto1 == proto2);
  EXPECT_FALSE(proto1 != proto2);
}

TEST(OperatorsTest,
     BitSequenceOperatorEqualsShouldReturnFalseIfDifferentPadding) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 987;
  bit_sequence1->bitmap = nullptr;
  bit_sequence2->bitmap = nullptr;

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_FALSE(proto1 == proto2);
  EXPECT_TRUE(proto1 != proto2);
}

TEST(OperatorsTest,
     BitSequenceOperatorEqualsShouldReturnFalseIfDifferentBitmapLength) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 789;
  bit_sequence1->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3, 4, 5});
  bit_sequence2->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3});

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_FALSE(proto1 == proto2);
  EXPECT_TRUE(proto1 != proto2);
}

TEST(
    OperatorsTest,
    BitSequenceOperatorEqualsShouldReturnFalseIfSameBitmapLengthButDifferentValues) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 789;
  bit_sequence1->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3});
  bit_sequence2->bitmap = MakeBytesArray(std::vector<uint8_t>{3, 2, 1});

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_FALSE(proto1 == proto2);
  EXPECT_TRUE(proto1 != proto2);
}

TEST(
    OperatorsTest,
    BitSequenceOperatorEqualsShouldReturnFalseIfArg1HasNullBitmapAndArg2HasNonNullBitmap) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 789;
  bit_sequence1->bitmap = nullptr;
  bit_sequence2->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3});

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_FALSE(proto1 == proto2);
  EXPECT_TRUE(proto1 != proto2);
}

TEST(
    OperatorsTest,
    BitSequenceOperatorEqualsShouldReturnFalseIfArg1HasNonNullBitmapAndArg2HasNullBitmap) {
  Message<google_firestore_v1_BitSequence> bit_sequence1;
  Message<google_firestore_v1_BitSequence> bit_sequence2;
  bit_sequence1->padding = 789;
  bit_sequence2->padding = 789;
  bit_sequence1->bitmap = MakeBytesArray(std::vector<uint8_t>{1, 2, 3});
  bit_sequence2->bitmap = nullptr;

  google_firestore_v1_BitSequence proto1 = *bit_sequence1;
  google_firestore_v1_BitSequence proto2 = *bit_sequence2;
  EXPECT_FALSE(proto1 == proto2);
  EXPECT_TRUE(proto1 != proto2);
}

// TODO(dconeybe): Add tests for google_firestore_v1_BloomFilter

}  //  namespace
}  //  namespace firestore
}  //  namespace firebase
