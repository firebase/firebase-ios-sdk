/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_TEST_UNIT_NANOPB_NANOPB_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_NANOPB_NANOPB_TESTING_H_

#include <utility>
#include <vector>

#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/nanopb/writer.h"
#include "Firestore/core/src/util/status_fwd.h"
#include "google/protobuf/message.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * Serializes the given libprotobuf message to the equivalent bytes, contained
 * in a blob.
 */
template <typename T>
ByteString ProtobufSerialize(const T& protobuf_message) {
  ByteStringWriter writer;

  size_t size = protobuf_message.ByteSizeLong();
  writer.Reserve(size);

  bool ok =
      protobuf_message.SerializeToArray(writer.pos(), static_cast<int>(size));

  // SerializeToArray can only fail if the buffer wasn't large enough.
  HARD_ASSERT(ok);

  writer.SetSize(size);
  return writer.Release();
}

/**
 * Decodes the given bytes into a libprotobuf message object.
 */
template <typename T>
T ProtobufParse(const ByteString& bytes) {
  T message;
  bool ok =
      message.ParseFromArray(bytes.data(), static_cast<int>(bytes.size()));
  EXPECT_TRUE(ok);
  return message;
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_NANOPB_NANOPB_TESTING_H_
