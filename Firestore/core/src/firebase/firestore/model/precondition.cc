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

#include "Firestore/core/src/firebase/firestore/model/precondition.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

Precondition::Precondition(Type type, SnapshotVersion update_time, bool exists)
    : type_(type), update_time_(std::move(update_time)), exists_(exists) {
}

/* static */
const Precondition& Precondition::Exists(bool exists) {
  static Precondition kExist{Type::Exists, SnapshotVersion::None(), true};
  static Precondition kNotExist{Type::Exists, SnapshotVersion::None(), false};
  return exists ? kExist : kNotExist;
}

/* static */
Precondition Precondition::UpdateTime(SnapshotVersion update_time) {
  FIREBASE_ASSERT_MESSAGE(update_time != SnapshotVersion::None(),
                          "Invalid update time");
  return Precondition{Type::UpdateTime, std::move(update_time), false};
}

/* static */
const Precondition& Precondition::None() {
  static Precondition kNoPrecondition{Type::None, SnapshotVersion::None(),
                                      false};
  return kNoPrecondition;
}

bool Precondition::IsValidFor(const MaybeDocument& maybe_doc) const {
  switch (type_) {
    case Type::UpdateTime:
      return maybe_doc.type() == MaybeDocument::Type::Document &&
             maybe_doc.version() == update_time_;
      break;
    case Type::Exists:
      if (exists_) {
        return maybe_doc.type() == MaybeDocument::Type::Document;
      } else {
        return maybe_doc.type() == MaybeDocument::Type::NoDocument;
      }
      break;
    case Type::None:
      FIREBASE_ASSERT_MESSAGE(IsNone(), "Precondition should be empty");
      return true;
    default:
      FIREBASE_ASSERT_MESSAGE(false, "Invalid precondition");
      break;
  }
}

bool Precondition::IsNone() const {
  return type_ == Type::None;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
