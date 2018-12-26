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

#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/local/document_reference.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;
using util::ComparisonResult;

bool operator==(const DocumentReference& lhs, const DocumentReference& rhs) {
  return lhs.key_ == rhs.key_ && lhs.ref_id_ == rhs.ref_id_;
}

size_t DocumentReference::Hash() const {
  return util::Hash(key_.ToString(), ref_id_);
}

std::string DocumentReference::ToString() const {
  return util::StringFormat("<DocumentReference: key=%s, id=%s>",
                            key_.ToString(), ref_id_);
}

/** Sorts document references by key then ID. */
bool DocumentReference::ByKey::operator()(const DocumentReference& lhs,
                                          const DocumentReference& rhs) const {
  util::Comparator<model::DocumentKey> key_less;
  if (key_less(lhs.key_, rhs.key_)) return true;
  if (key_less(rhs.key_, lhs.key_)) return false;

  util::Comparator<int32_t> id_less;
  return id_less(lhs.ref_id_, rhs.ref_id_);
}

/** Sorts document references by ID then key. */
bool DocumentReference::ById::operator()(const DocumentReference& lhs,
                                         const DocumentReference& rhs) const {
  util::Comparator<int32_t> id_less;
  if (id_less(lhs.ref_id_, rhs.ref_id_)) return true;
  if (id_less(rhs.ref_id_, lhs.ref_id_)) return false;

  util::Comparator<model::DocumentKey> key_less;
  return key_less(lhs.key_, rhs.key_);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
