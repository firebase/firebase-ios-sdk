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

#include <pb.h>
#include <pb_encode.h>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "gtest/gtest.h"

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
  SerializerTest() : serializer(/*DatabaseId("p", "d")*/) {
  }
  Serializer serializer;

  void ExpectRoundTrip(const FieldValue& model,
                       const Serializer::TypedValue& proto,
                       FieldValue::Type type) {
    EXPECT_EQ(type, model.type());
    EXPECT_EQ(type, proto.type);
    Serializer::TypedValue actual_proto = serializer.EncodeFieldValue(model);
    EXPECT_EQ(type, actual_proto.type);
    EXPECT_EQ(proto, actual_proto);
    EXPECT_EQ(model, serializer.DecodeFieldValue(proto));
  }

  void ExpectRoundTrip(const Serializer::TypedValue& proto,
                       std::vector<uint8_t> bytes,
                       FieldValue::Type type) {
    EXPECT_EQ(type, proto.type);
    std::vector<uint8_t> actual_bytes;
    Serializer::EncodeTypedValue(proto, &actual_bytes);
    EXPECT_EQ(bytes, actual_bytes);
    Serializer::TypedValue actual_proto = Serializer::DecodeTypedValue(bytes);
    EXPECT_EQ(type, actual_proto.type);
    EXPECT_EQ(proto, actual_proto);
  }
};

TEST_F(SerializerTest, EncodesNullModelToProto) {
  FieldValue model = FieldValue::NullValue();
  Serializer::TypedValue proto{FieldValue::Type::Null,
                               google_firestore_v1beta1_Value_init_default};
  // sanity check (the _init_default above should set this to _NULL_VALUE)
  EXPECT_EQ(google_protobuf_NullValue_NULL_VALUE, proto.value.null_value);
  ExpectRoundTrip(model, proto, FieldValue::Type::Null);
}

TEST_F(SerializerTest, EncodesNullProtoToBytes) {
  Serializer::TypedValue proto{FieldValue::Type::Null,
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
  std::vector<uint8_t> bytes{0x58, 0x00};
  ExpectRoundTrip(proto, bytes, FieldValue::Type::Null);
}

// TODO(rsgowman): Test [en|de]coding multiple protos into the same output
// vector.
