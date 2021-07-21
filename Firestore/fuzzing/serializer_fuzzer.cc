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

#include <cstddef>
#include <cstdint>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/read_context.h"

using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::nanopb::Message;
using firebase::firestore::nanopb::StringReader;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::ReadContext;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  Serializer serializer{DatabaseId{"project", DatabaseId::kDefault}};
  try {
    // Try to decode the received data using the serializer.
    StringReader reader{data, size};
    auto message = Message<google_firestore_v1_Value>::TryParse(&reader);
    ReadContext context;
    serializer.DecodeFieldValue(&context, *message);
  } catch (...) {
    // Ignore caught errors and assertions because fuzz testing is looking for
    // crashes and memory errors.
  }
  return 0;
}
