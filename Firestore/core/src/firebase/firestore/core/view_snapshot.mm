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

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"

namespace firebase {
namespace firestore {
namespace core {

namespace objc = util::objc;
using model::DocumentKey;
using util::StringFormat;

// DocumentViewChange

std::string DocumentViewChange::ToString() const {
  return StringFormat("<DocumentViewChange doc:%s type:%s>",
                      util::ToString(document()), type());
}

size_t DocumentViewChange::Hash() const {
  size_t document_hash = static_cast<size_t>([document() hash]);
  return util::Hash(document_hash, static_cast<int>(type()));
}

bool operator==(const DocumentViewChange& lhs, const DocumentViewChange& rhs) {
  return objc::Equals(lhs.document(), rhs.document()) &&
         lhs.type() == rhs.type();
}

// DocumentViewChangeSet

void DocumentViewChangeSet::AddChange(DocumentViewChange&& change) {
  const DocumentKey& key = change.document().key;
  auto old_change_iter = change_map_.find(key);
  if (old_change_iter == change_map_.end()) {
    change_map_ = change_map_.insert(key, change);
    return;
  }

  const DocumentViewChange& old = old_change_iter->second;
  DocumentViewChange::Type old_type = old.type();
  DocumentViewChange::Type new_type = change.type();

  // Merge the new change with the existing change.
  if (new_type != DocumentViewChange::Type::kAdded &&
      old_type == DocumentViewChange::Type::kMetadata) {
    change_map_ = change_map_.insert(key, change);

  } else if (new_type == DocumentViewChange::Type::kMetadata &&
             old_type != DocumentViewChange::Type::kRemoved) {
    DocumentViewChange new_change{change.document(), old_type};
    change_map_ = change_map_.insert(key, new_change);

  } else if (new_type == DocumentViewChange::Type::kModified &&
             old_type == DocumentViewChange::Type::kModified) {
    DocumentViewChange new_change{change.document(),
                                  DocumentViewChange::Type::kModified};
    change_map_ = change_map_.insert(key, new_change);

  } else if (new_type == DocumentViewChange::Type::kModified &&
             old_type == DocumentViewChange::Type::kAdded) {
    DocumentViewChange new_change{change.document(),
                                  DocumentViewChange::Type::kAdded};
    change_map_ = change_map_.insert(key, new_change);

  } else if (new_type == DocumentViewChange::Type::kRemoved &&
             old_type == DocumentViewChange::Type::kAdded) {
    change_map_ = change_map_.erase(key);

  } else if (new_type == DocumentViewChange::Type::kRemoved &&
             old_type == DocumentViewChange::Type::kModified) {
    DocumentViewChange new_change{old.document(),
                                  DocumentViewChange::Type::kRemoved};
    change_map_ = change_map_.insert(key, new_change);

  } else if (new_type == DocumentViewChange::Type::kAdded &&
             old_type == DocumentViewChange::Type::kRemoved) {
    DocumentViewChange new_change{change.document(),
                                  DocumentViewChange::Type::kModified};
    change_map_ = change_map_.insert(key, new_change);

  } else {
    // This includes these cases, which don't make sense:
    // Added -> Added
    // Removed -> Removed
    // Modified -> Added
    // Removed -> Modified
    // Metadata -> Added
    // Removed -> Metadata
    HARD_FAIL("Unsupported combination of changes: %s after %s", new_type,
              old_type);
  }
}

std::vector<DocumentViewChange> DocumentViewChangeSet::GetChanges() const {
  std::vector<DocumentViewChange> changes;
  for (const auto& kv : change_map_) {
    const DocumentViewChange& change = kv.second;
    changes.push_back(change);
  }
  return changes;
}

std::string DocumentViewChangeSet::ToString() const {
  return util::ToString(change_map_);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
