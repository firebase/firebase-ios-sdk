/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

#include <gtest/gtest.h>
#include <pb.h>
#include <pb_encode.h>

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"

using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldValue;
using firebase::firestore::remote::Serializer;

TEST(Serializer, CanLinkToNanopb) {
  // This test doesn't actually do anything interesting as far as actually using
  // nanopb is concerned but that it can run at all is proof that all the
  // libraries required for nanopb to work are actually linked correctly into
  // the test.
  pb_ostream_from_buffer(NULL, 0);
}

// Fixture for running serializer tests.
class SerializerTest : public ::testing::Test {
 public:
  SerializerTest() : serializer(DatabaseId("p", "d")) {
  }
  Serializer serializer;

  void ExpectRoundTrip(const FieldValue& model,
                       const Serializer::ValueWithType& proto,
                       FieldValue::Type type) {
    EXPECT_EQ(type, model.type());
    EXPECT_EQ(type, proto.type);
    Serializer::ValueWithType actual_proto = serializer.EncodeFieldValue(model);
    EXPECT_EQ(type, actual_proto.type);
    EXPECT_EQ(proto, actual_proto);
    EXPECT_EQ(model, serializer.DecodeFieldValue(proto));
  }

  void ExpectRoundTrip(const Serializer::ValueWithType& proto,
                       const uint8_t* bytes,
                       size_t bytes_len,
                       FieldValue::Type type) {
    EXPECT_EQ(type, proto.type);
    // TODO(rsgowman): How big should this buffer be? Unclear; see TODO in
    // remote/serializer.h on the Serializer::EncodeValueWithType() method.
    // Hardcode to 1k for now.
    uint8_t actual_bytes[1024];
    size_t actual_bytes_len = sizeof(actual_bytes);
    Serializer::EncodeValueWithType(proto, actual_bytes, &actual_bytes_len);
    EXPECT_EQ(bytes_len, actual_bytes_len);
    EXPECT_EQ(memcmp(bytes, actual_bytes, bytes_len), 0);
    Serializer::ValueWithType actual_proto =
        Serializer::DecodeValueWithType(bytes, bytes_len);
    EXPECT_EQ(type, actual_proto.type);
    EXPECT_EQ(proto, actual_proto);
  }
};

TEST_F(SerializerTest, EncodesNullModelToProto) {
  FieldValue model = FieldValue::NullValue();
  Serializer::ValueWithType proto{FieldValue::Type::Null,
                                  google_firestore_v1beta1_Value_init_default};
  // sanity check (the _init_default above should set this to _NULL_VALUE)
  EXPECT_EQ(google_protobuf_NullValue_NULL_VALUE, proto.value.null_value);
  ExpectRoundTrip(model, proto, FieldValue::Type::Null);
}

TEST_F(SerializerTest, EncodesNullProtoToBytes) {
  Serializer::ValueWithType proto{FieldValue::Type::Null,
                                  google_firestore_v1beta1_Value_init_default};
  // sanity check (the _init_default above should set this to _NULL_VALUE)
  EXPECT_EQ(google_protobuf_NullValue_NULL_VALUE, proto.value.null_value);

  /* NB: proto bytes were created via:
       echo 'null_value: NULL_VALUE' \
         | ./build/external/protobuf/src/protobuf-build/src/protoc \
             -I./Firestore/Protos/protos \
             -I./build/external/protobuf/src/protobuf/src/ \
             --encode=google.firestore.v1beta1.Value \
             google/firestore/v1beta1/document.proto \
             > output.bin
   */
  uint8_t bytes[] = {0x58, 0x00};
  ExpectRoundTrip(proto, bytes, sizeof(bytes), FieldValue::Type::Null);
}
