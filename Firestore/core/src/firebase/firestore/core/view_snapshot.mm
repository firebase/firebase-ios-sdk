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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"

namespace firebase {
namespace firestore {
namespace core {

namespace objc = util::objc;
using model::DocumentKey;
using model::DocumentKeySet;
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

// ViewSnapshot

ViewSnapshot::ViewSnapshot(FSTQuery* query,
                           FSTDocumentSet* documents,
                           FSTDocumentSet* old_documents,
                           std::vector<DocumentViewChange> document_changes,
                           model::DocumentKeySet mutated_keys,
                           bool from_cache,
                           bool sync_state_changed,
                           bool excludes_metadata_changes)
    : query_{query},
      documents_{documents},
      old_documents_{old_documents},
      document_changes_{std::move(document_changes)},
      mutated_keys_{std::move(mutated_keys)},
      from_cache_{from_cache},
      sync_state_changed_{sync_state_changed},
      excludes_metadata_changes_{excludes_metadata_changes} {
}

ViewSnapshot ViewSnapshot::FromInitialDocuments(
    FSTQuery* query,
    FSTDocumentSet* documents,
    DocumentKeySet mutated_keys,
    bool from_cache,
    bool excludes_metadata_changes) {
  std::vector<DocumentViewChange> view_changes;
  for (FSTDocument* doc in documents.documentEnumerator) {
    view_changes.emplace_back(doc, DocumentViewChange::Type::kAdded);
  }

  return ViewSnapshot{
      query, documents,
      /*old_documents=*/
      [FSTDocumentSet documentSetWithComparator:query.comparator],
      std::move(view_changes), std::move(mutated_keys), from_cache,
      /*sync_state_changed=*/true, excludes_metadata_changes};
}

std::string ViewSnapshot::ToString() const {
  return StringFormat(
      "<ViewSnapshot query: %s documents: %s old_documents: %s changes: %s "
      "from_cache: %s mutated_keys: %s sync_state_changed: %s "
      "excludes_metadata_changes: %s>",
      query(), documents(), old_documents(),
      objc::Description(document_changes()), from_cache(),
      mutated_keys().size(), sync_state_changed(), excludes_metadata_changes());
}

size_t ViewSnapshot::Hash() const {
  // Note: We are omitting `mutated_keys_` from the hash, since we don't have a
  // straightforward way to compute its hash value. Since `ViewSnapshot` is
  // currently not stored in any dictionaries, this has no side effects.

  return util::Hash([query() hash], [documents() hash], [old_documents() hash],
                    document_changes(), from_cache(), sync_state_changed(),
                    excludes_metadata_changes());
}

bool operator==(const ViewSnapshot& lhs, const ViewSnapshot& rhs) {
  return objc::Equals(lhs.query(), rhs.query()) &&
         objc::Equals(lhs.documents(), rhs.documents()) &&
         objc::Equals(lhs.old_documents(), rhs.old_documents()) &&
         lhs.document_changes() == rhs.document_changes() &&
         lhs.from_cache() == rhs.from_cache() &&
         lhs.mutated_keys() == rhs.mutated_keys() &&
         lhs.sync_state_changed() == rhs.sync_state_changed() &&
         lhs.excludes_metadata_changes() == rhs.excludes_metadata_changes();
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
