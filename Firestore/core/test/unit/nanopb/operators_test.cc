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

/**
 * Base class for test fixtures that test the operator overloads of proto types.
 *
 * @tparam RawProtoT The raw proto struct whose operator(s) are being tested,
 * such as `google_firestore_v1_BitSequence`.
 */
template <typename RawProtoT>
class BaseOperatorsTest : public ::testing::Test {
 protected:
  static void TestOperatorEquals(bool expected_result,
                                 nanopb::Message<RawProtoT> message1,
                                 nanopb::Message<RawProtoT> message2) {
    const RawProtoT& proto1 = *message1;
    const RawProtoT& proto2 = *message2;
    EXPECT_EQ(proto1 == proto2, expected_result);
    EXPECT_NE(proto1 != proto2, expected_result);
  }
};

////////////////////////////////////////////////////////////////////////////////
// Tests for operator==() for google_firestore_v1_BitSequence
////////////////////////////////////////////////////////////////////////////////

class NanopbOperatorsTest_BitSequence
    : public BaseOperatorsTest<google_firestore_v1_BitSequence> {
 public:
  static constexpr int32_t kSamplePadding = 567;
  static constexpr int32_t kDifferentSamplePadding = 765;
  static const absl::optional<std::vector<uint8_t>> kNullBitmap;
  static const std::vector<uint8_t> kSampleBitmap;
  static const std::vector<uint8_t> kDifferentSampleBitmap;

  // Stores the `padding` and `bitmap` of a `google_firestore_v1_BitSequence`
  // proto, and enables creating `Message` objects from them.
  class ProtoFieldValues final {
   public:
    ProtoFieldValues(int32_t padding,
                     const absl::optional<std::vector<uint8_t>>& bitmap)
        : padding_(padding), bitmap_(bitmap) {
    }

    ProtoFieldValues(int32_t padding, const std::vector<uint8_t>& bitmap)
        : ProtoFieldValues(padding,
                           absl::optional<std::vector<uint8_t>>(bitmap)) {
    }

    ProtoFieldValues(const absl::optional<std::vector<uint8_t>>& bitmap)
        : ProtoFieldValues(kSamplePadding, bitmap) {
    }

    ProtoFieldValues(const std::vector<uint8_t>& bitmap)
        : ProtoFieldValues(kSamplePadding, bitmap) {
    }

    ProtoFieldValues(int32_t padding)
        : ProtoFieldValues(padding, kSampleBitmap) {
    }

    nanopb::Message<google_firestore_v1_BitSequence> CreateMessage() const {
      return nanopb::Message<google_firestore_v1_BitSequence>(CreateProto());
    }

    // The caller assumes ownership of the returned object, and is, therefore,
    // responsible for freeing any dynamically-allocated memory that it
    // references, such as memory allocated by `nanopb::MakeBytesArray()`.
    google_firestore_v1_BitSequence CreateProto() const {
      google_firestore_v1_BitSequence proto =
          google_firestore_v1_BitSequence_init_zero;
      proto.padding = padding_;
      if (bitmap_.has_value()) {
        proto.bitmap = nanopb::MakeBytesArray(bitmap_.value());
      }
      return proto;
    }

   private:
    int32_t padding_;
    absl::optional<std::vector<uint8_t>> bitmap_;
  };

 protected:
  static void TestOperatorEquals(bool expected_result,
                                 const ProtoFieldValues& values1,
                                 const ProtoFieldValues& values2) {
    return BaseOperatorsTest::TestOperatorEquals(
        expected_result, values1.CreateMessage(), values2.CreateMessage());
  }
};

const absl::optional<std::vector<uint8_t>>
    NanopbOperatorsTest_BitSequence::kNullBitmap(absl::nullopt);
const std::vector<uint8_t> NanopbOperatorsTest_BitSequence::kSampleBitmap(
    {100, 101, 102, 103});
const std::vector<uint8_t>
    NanopbOperatorsTest_BitSequence::kDifferentSampleBitmap({200, 201, 202,
                                                             203});

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnTrueIfBothMessagesHaveSamePaddingAndNullBitmap) {
  TestOperatorEquals(true, {kSamplePadding, kNullBitmap},
                     {kSamplePadding, kNullBitmap});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnTrueIfBothMessagesHaveSamePaddingAndBitmap) {
  TestOperatorEquals(true, {kSamplePadding, kSampleBitmap},
                     {kSamplePadding, kSampleBitmap});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseIfMessageHaveDifferentPadding) {
  TestOperatorEquals(false, {kSamplePadding}, {kDifferentSamplePadding});
}

TEST_F(
    NanopbOperatorsTest_BitSequence,
    EqualsShouldReturnFalseIfMessage1HasNonNullBitmapButMessage2HasNullBitmap) {
  TestOperatorEquals(false, {kSampleBitmap}, {kNullBitmap});
}

TEST_F(
    NanopbOperatorsTest_BitSequence,
    EqualsShouldReturnFalseIfMessage1HasNullBitmapButMessage2HasNonNullBitmap) {
  TestOperatorEquals(false, {kNullBitmap}, {kSampleBitmap});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseMessagesHaveSameSizeBitmapsButDifferentValues) {
  TestOperatorEquals(false, {{1, 2, 3, 4}}, {{4, 3, 2, 1}});
}

TEST_F(NanopbOperatorsTest_BitSequence,
       EqualsShouldReturnFalseMessagesHaveDifferentSizeBitmaps) {
  TestOperatorEquals(false, {{1, 2, 3}}, {{1, 2, 3, 4}});
}

////////////////////////////////////////////////////////////////////////////////
// Tests for operator==() for google_firestore_v1_BloomFilter
////////////////////////////////////////////////////////////////////////////////

class NanopbOperatorsTest_BloomFilter
    : public BaseOperatorsTest<google_firestore_v1_BloomFilter> {
 public:
  static constexpr int32_t kSampleHashCount = 17;
  static constexpr int32_t kDifferentSampleHashCount = 71;
  static const absl::optional<NanopbOperatorsTest_BitSequence::ProtoFieldValues>
      kNoBits;
  static const NanopbOperatorsTest_BitSequence::ProtoFieldValues kSampleBits;
  static const NanopbOperatorsTest_BitSequence::ProtoFieldValues
      kDifferentSampleBits;

  // Stores the `hash_count` and `bits` of a `google_firestore_v1_BloomFilter`
  // proto, and enables creating `Message` objects from them.
  class ProtoFieldValues final {
   public:
    ProtoFieldValues(
        int32_t hash_count,
        const absl::optional<NanopbOperatorsTest_BitSequence::ProtoFieldValues>&
            bits)
        : hash_count_(hash_count), bits_(bits) {
    }

    ProtoFieldValues(
        int32_t hash_count,
        const NanopbOperatorsTest_BitSequence::ProtoFieldValues& bits)
        : ProtoFieldValues(
              hash_count,
              absl::optional<NanopbOperatorsTest_BitSequence::ProtoFieldValues>(
                  bits)) {
    }

    ProtoFieldValues(
        const absl::optional<NanopbOperatorsTest_BitSequence::ProtoFieldValues>&
            bits)
        : ProtoFieldValues(kSampleHashCount, bits) {
    }

    ProtoFieldValues(
        const NanopbOperatorsTest_BitSequence::ProtoFieldValues& bits)
        : ProtoFieldValues(kSampleHashCount, bits) {
    }

    ProtoFieldValues(int32_t hash_count)
        : ProtoFieldValues(hash_count, kSampleBits) {
    }

    nanopb::Message<google_firestore_v1_BloomFilter> CreateMessage() const {
      return nanopb::Message<google_firestore_v1_BloomFilter>(CreateProto());
    }

    // The caller assumes ownership of the returned object, and is, therefore,
    // responsible for freeing any dynamically-allocated memory that it
    // references, such as memory allocated by `nanopb::MakeBytesArray()`.
    google_firestore_v1_BloomFilter CreateProto() const {
      google_firestore_v1_BloomFilter proto =
          google_firestore_v1_BloomFilter_init_zero;
      proto.hash_count = hash_count_;
      if (bits_.has_value()) {
        proto.bits = bits_->CreateProto();
        proto.has_bits = true;
      }
      return proto;
    }

   private:
    int32_t hash_count_;
    absl::optional<NanopbOperatorsTest_BitSequence::ProtoFieldValues> bits_;
  };

 protected:
  static void TestOperatorEquals(bool expected_result,
                                 ProtoFieldValues values1,
                                 ProtoFieldValues values2) {
    return BaseOperatorsTest::TestOperatorEquals(
        expected_result, values1.CreateMessage(), values2.CreateMessage());
  }
};

const absl::optional<NanopbOperatorsTest_BitSequence::ProtoFieldValues>
    NanopbOperatorsTest_BloomFilter::kNoBits(absl::nullopt);
const NanopbOperatorsTest_BitSequence::ProtoFieldValues
    NanopbOperatorsTest_BloomFilter::kSampleBits(
        NanopbOperatorsTest_BitSequence::kSamplePadding,
        NanopbOperatorsTest_BitSequence::kSampleBitmap);
const NanopbOperatorsTest_BitSequence::ProtoFieldValues
    NanopbOperatorsTest_BloomFilter::kDifferentSampleBits(
        NanopbOperatorsTest_BitSequence::kDifferentSamplePadding,
        NanopbOperatorsTest_BitSequence::kDifferentSampleBitmap);

TEST_F(NanopbOperatorsTest_BloomFilter,
       EqualsShouldReturnTrueIfBothMessagesHaveSameHashCountAndNoBits) {
  TestOperatorEquals(true, {kSampleHashCount, kNoBits},
                     {kSampleHashCount, kNoBits});
}

TEST_F(NanopbOperatorsTest_BloomFilter,
       EqualsShouldReturnTrueIfBothMessagesHaveSameHashCountAndBits) {
  TestOperatorEquals(true, {kSampleHashCount, kSampleBits},
                     {kSampleHashCount, kSampleBits});
}

TEST_F(NanopbOperatorsTest_BloomFilter,
       EqualsShouldReturnFalseIfMessageHaveDifferentHashCount) {
  TestOperatorEquals(false, {kSampleHashCount}, {kDifferentSampleHashCount});
}

TEST_F(NanopbOperatorsTest_BloomFilter,
       EqualsShouldReturnFalseIfMessage1HasBitsButMessage2DoesNotHaveBits) {
  TestOperatorEquals(false, {kSampleBits}, {kNoBits});
}

TEST_F(NanopbOperatorsTest_BloomFilter,
       EqualsShouldReturnFalseIfMessage1DoesNotHavBitsButMessage2HasBits) {
  TestOperatorEquals(false, {kNoBits}, {kSampleBits});
}

TEST_F(NanopbOperatorsTest_BloomFilter,
       EqualsShouldReturnFalseIfMessagesHaveDifferentBits) {
  TestOperatorEquals(false, {kSampleBits}, {kDifferentSampleBits});
}

}  //  namespace
}  //  namespace firestore
}  //  namespace firebase
