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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_TAG_H__
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_TAG_H__

#include <pb.h>

namespace firebase {
namespace firestore {
namespace nanopb {

/**
 * Represents a nanopb tag.
 *
 * field_number is one of the field tags that nanopb generates based off of
 * the proto messages. They're typically named in the format:
 * <parentNameSpace>_<childNameSpace>_<message>_<field>_tag, e.g.
 * google_firestore_v1beta1_Document_name_tag.
 */
struct Tag {
  Tag() {
  }

  Tag(pb_wire_type_t w, uint32_t f) : wire_type{w}, field_number{f} {
  }

  pb_wire_type_t wire_type = PB_WT_VARINT;
  uint32_t field_number = 0u;
};

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_TAG_H_
