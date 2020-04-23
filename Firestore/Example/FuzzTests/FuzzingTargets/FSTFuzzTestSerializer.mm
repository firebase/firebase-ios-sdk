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

#import <Foundation/Foundation.h>
#include <cstddef>
#include <cstdint>

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestSerializer.h"

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/remote/serializer.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

using firebase::firestore::model::DatabaseId;
using firebase::firestore::nanopb::Message;
using firebase::firestore::nanopb::StringReader;
using firebase::firestore::remote::Serializer;

int FuzzTestDeserialization(const uint8_t *data, size_t size) {
  Serializer serializer{DatabaseId{"project"}};

  @autoreleasepool {
    @try {
      StringReader reader{data, size};
      auto message = Message<google_firestore_v1_Value>::TryParse(&reader);
      serializer.DecodeFieldValue(&reader, *message);
    } @catch (...) {
      // Caught exceptions are ignored because the input might be malformed and
      // the deserialization might throw an error as intended. Fuzzing focuses on
      // runtime errors that are detected by the sanitizers.
    }
  }

  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
