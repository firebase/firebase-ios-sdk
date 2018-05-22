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

#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"

#include <utility>

namespace firebase {
namespace firestore {
namespace model {

MaybeDocument::MaybeDocument(DocumentKey key, SnapshotVersion version)
    : key_(std::move(key)), version_(std::move(version)) {
}

bool MaybeDocument::Equals(const MaybeDocument& other) const {
  return type_ == other.type_ && version_ == other.version_ &&
         key_ == other.key_;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
