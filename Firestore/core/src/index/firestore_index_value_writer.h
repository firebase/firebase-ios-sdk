/*
 * Copyright 2022 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_INDEX_FIRESTORE_INDEX_VALUE_WRITER_H_
#define FIRESTORE_CORE_SRC_INDEX_FIRESTORE_INDEX_VALUE_WRITER_H_

#include "Firestore/core/src/index/index_byte_encoder.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"

namespace firebase {
namespace firestore {
namespace index {

/**
 * Writes an index value using the given encoder. The encoder writes the encoded
 * bytes into a buffer maintained by `IndexEncodingBuffer` who owns the
 * `encoder`.
 */
void WriteIndexValue(const google_firestore_v1_Value& value,
                     DirectionalIndexByteEncoder* encoder);

}  // namespace index
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_INDEX_FIRESTORE_INDEX_VALUE_WRITER_H_
