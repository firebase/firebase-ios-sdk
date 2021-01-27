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

#include "Firestore/core/src/bundle/bundle_serializer.h"

#include "Firestore/Protos/cpp/firestore/bundle.pb.h"
#include "google/protobuf/util/json_util.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace bundle {
namespace {

using google::protobuf::Message;
using google::protobuf::util::MessageToJsonString;
using nlohmann::json;
using ProtoBundleMetadata = ::firestore::BundleMetadata;
using util::ReadContext;

TEST(BundleSerializerTest, DecodesBundleMetadata) {
  auto proto_metadata = ProtoBundleMetadata{};
  *proto_metadata.mutable_id() = "bundle-1";
  proto_metadata.mutable_create_time()->set_seconds(2);
  proto_metadata.mutable_create_time()->set_nanos(3);
  proto_metadata.set_version(1);
  proto_metadata.set_total_bytes(123456789987654321L);
  proto_metadata.set_total_documents(5);
  std::string json_string;
  MessageToJsonString(proto_metadata, &json_string);

  BundleSerializer serializer;
  ReadContext context;
  BundleMetadata actual =
      serializer.DecodeBundleMetadata(&context, json_string);

  EXPECT_TRUE(context.ok());
  EXPECT_EQ(proto_metadata.id(), actual.bundle_id());
  EXPECT_EQ(proto_metadata.create_time().seconds(),
            actual.create_time().timestamp().seconds());
  EXPECT_EQ(proto_metadata.create_time().nanos(),
            actual.create_time().timestamp().nanoseconds());
  EXPECT_EQ(proto_metadata.version(), actual.version());
  EXPECT_EQ(proto_metadata.total_bytes(), actual.total_bytes());
  EXPECT_EQ(proto_metadata.total_documents(), actual.total_documents());
}

TEST(BundleSerializerTest, DecodesInvalidBundleMetadataReportsError) {
  auto proto_metadata = ProtoBundleMetadata{};
  *proto_metadata.mutable_id() = "bundle-1";
  proto_metadata.mutable_create_time()->set_seconds(2);
  proto_metadata.mutable_create_time()->set_nanos(3);
  proto_metadata.set_version(1);
  proto_metadata.set_total_bytes(123456789987654321L);
  proto_metadata.set_total_documents(5);
  std::string json_string;
  MessageToJsonString(proto_metadata, &json_string);
  auto invalid = "123" + json_string;

  BundleSerializer serializer;
  ReadContext context;
  serializer.DecodeBundleMetadata(&context, invalid);

  EXPECT_FALSE(context.ok());

  std::string to_replace("123456789987654321");
  auto start = json_string.find(to_replace);
  json_string.replace(start, to_replace.size(), "xxxyyyzzz");

  ReadContext new_context;
  serializer.DecodeBundleMetadata(&new_context, json_string);

  EXPECT_FALSE(new_context.ok());
}

}  //  namespace
}  //  namespace bundle
}  //  namespace firestore
}  //  namespace firebase
