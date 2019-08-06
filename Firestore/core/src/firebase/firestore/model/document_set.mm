/*
 * Copyright 2017 Google
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

#include "Firestore/core/src/firebase/firestore/model/document_set.h"

#include <ostream>
#include <utility>

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/immutable/sorted_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"
#include "absl/algorithm/container.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace model {

using immutable::SortedSet;

DocumentComparator DocumentComparator::ByKey() {
  return DocumentComparator([](const Document& lhs, const Document& rhs) {
    return util::Compare(lhs.key(), rhs.key());
  });
}

DocumentSet::DocumentSet(DocumentComparator&& comparator)
    : index_{}, sorted_set_{std::move(comparator)} {
}

bool operator==(const DocumentSet& lhs, const DocumentSet& rhs) {
  return absl::c_equal(lhs.sorted_set_, rhs.sorted_set_,
                       [](FSTDocument* left_doc, FSTDocument* right_doc) {
                         return [left_doc isEqual:right_doc];
                       });
}

std::string DocumentSet::ToString() const {
  return util::ToString(sorted_set_);
}

std::ostream& operator<<(std::ostream& os, const DocumentSet& set) {
  return os << set.ToString();
}

size_t DocumentSet::Hash() const {
  size_t hash = 0;
  for (FSTDocument* doc : sorted_set_) {
    hash = 31 * hash + [doc hash];
  }
  return hash;
}

bool DocumentSet::ContainsKey(const DocumentKey& key) const {
  return index_.underlying_map().find(key) != index_.underlying_map().end();
}

FSTDocument* _Nullable DocumentSet::GetDocument(const DocumentKey& key) const {
  auto found = index_.underlying_map().find(key);
  return found != index_.underlying_map().end()
             ? static_cast<FSTDocument*>(found->second)
             : nil;
}

FSTDocument* _Nullable DocumentSet::GetFirstDocument() const {
  auto result = sorted_set_.min();
  return result != sorted_set_.end() ? *result : nil;
}

FSTDocument* _Nullable DocumentSet::GetLastDocument() const {
  auto result = sorted_set_.max();
  return result != sorted_set_.end() ? *result : nil;
}

size_t DocumentSet::IndexOf(const DocumentKey& key) const {
  FSTDocument* doc = GetDocument(key);
  return doc ? sorted_set_.find_index(doc) : npos;
}

DocumentSet DocumentSet::insert(FSTDocument* _Nullable document) const {
  // TODO(mcg): look into making document nonnull.
  if (!document) {
    return *this;
  }

  // Remove any prior mapping of the document's key before adding, preventing
  // sortedSet from accumulating values that aren't in the index.
  DocumentSet removed = erase(document.key);

  DocumentMap index = removed.index_.insert(document.key, document);
  SetType set = removed.sorted_set_.insert(document);
  return {std::move(index), std::move(set)};
}

DocumentSet DocumentSet::erase(const DocumentKey& key) const {
  FSTDocument* doc = GetDocument(key);
  if (!doc) {
    return *this;
  }

  DocumentMap index = index_.erase(key);
  SetType set = sorted_set_.erase(doc);
  return {std::move(index), std::move(set)};
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
