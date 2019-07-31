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

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

using firebase::firestore::model::DatabaseId;
using firebase::firestore::nanopb::Reader;
using firebase::firestore::remote::Serializer;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  Serializer serializer{DatabaseId{"project", DatabaseId::kDefault}};
  try {
    // Try to decode the received data using the serializer.
    Reader reader{data, size};
    (void)reader;
    // TODO(varconst): reenable this test
    // auto val = serializer.DecodeFieldValue(&reader);
  } catch (...) {
    // Ignore caught errors and assertions because fuzz testing is looking for
    // crashes and memory errors.
  }
  return 0;
}
