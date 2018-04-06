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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_PRECONDITION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_PRECONDITION_H_

#include <memory>
#include <utility>

#if defined(__OBJC__)
#import "FIRTimestamp.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#endif  // defined(__OBJC__)

#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * Encodes a precondition for a mutation. This follows the model that the
 * backend accepts with the special case of an explicit "empty" precondition
 * (meaning no precondition).
 */
class Precondition {
 public:
  enum class Type {
    None,
    Exists,
    UpdateTime,
  };

  /** Creates a new Precondition with an exists flag. */
  static const Precondition& Exists(bool exists);

  /** Creates a new Precondition based on a time the document exists at. */
  static Precondition UpdateTime(SnapshotVersion update_time);

  /** Returns a precondition representing no precondition. */
  static const Precondition& None();

  /**
   * Returns true if the preconditions is valid for the given document (or null
   * if no document is available).
   */
  bool IsValidFor(const MaybeDocument& maybe_doc) const;

  /** Returns whether this Precondition represents no precondition. */
  bool IsNone() const;

  const SnapshotVersion& update_time() const {
    return update_time_;
  }

#if defined(__OBJC__)
  // Objective-C requires a default constructor.
  Precondition()
      : type_(Type::None),
        update_time_(SnapshotVersion::None()),
        exists_(false) {
  }

  // MaybeDocument is not fully ported yet. So we suppose this addition helper.
  bool IsValidFor(FSTMaybeDocument* maybe_doc) const {
    switch (type_) {
      case Type::UpdateTime:
        return [maybe_doc isKindOfClass:[FSTDocument class]] &&
               firebase::firestore::model::SnapshotVersion(maybe_doc.version) ==
                   update_time_;
        break;
      case Type::Exists:
        if (exists_) {
          return [maybe_doc isKindOfClass:[FSTDocument class]];
        } else {
          return maybe_doc == nil ||
                 [maybe_doc isKindOfClass:[FSTDeletedDocument class]];
        }
        break;
      case Type::None:
        FIREBASE_ASSERT_MESSAGE(IsNone(), "Precondition should be empty");
        return true;
        break;
      default:
        FIREBASE_ASSERT_MESSAGE(false, "Invalid precondition");
        break;
    }
  }

  bool operator==(const Precondition& other) const {
    return update_time_ == other.update_time_ && exists_ == other.exists_;
  }

  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  NSUInteger Hash() const {
    NSUInteger hash = std::hash<Timestamp>()(update_time_.timestamp());
    hash = hash * 31 + exists_;
    return hash;
  }

  NSString* description() const {
    switch (type_) {
      case Type::None:
        return @"<Precondition <none>>";
        break;
      case Type::Exists:
        if (exists_) {
          return @"<Precondition exists=yes>";
        } else {
          return @"<Precondition exists=no>";
        }
        break;
      case Type::UpdateTime:
        return [NSString
            stringWithFormat:@"<Precondition update_time=%s>",
                             update_time_.timestamp().ToString().c_str()];
        break;
      default:
        // We do not raise assertion here. This function is mainly used in
        // logging.
        return @"<Precondition invalid>";
        break;
    }
  }
#endif  // defined(__OBJC__)

 private:
  Precondition(Type type, SnapshotVersion update_time, bool exists);

  // The actual time of this precondition.
  Type type_ = Type::None;

  // For UpdateTime type, preconditions a mutation based on the last updateTime.
  SnapshotVersion update_time_;

  // For Exists type, preconditions a mutation based on whether the document
  // exists.
  bool exists_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_PRECONDITION_H_
