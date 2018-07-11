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

#include "Firestore/core/src/firebase/firestore/core/query.h"

#include <algorithm>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace core {

using model::Document;
using model::DocumentKey;
using model::ResourcePath;

bool Query::Matches(const Document& doc) const {
  return MatchesPath(doc) && MatchesOrderBy(doc) && MatchesFilters(doc) &&
         MatchesBounds(doc);
}

bool Query::MatchesPath(const Document& doc) const {
  ResourcePath doc_path = doc.key().path();
  if (DocumentKey::IsDocumentKey(path_)) {
    return path_ == doc_path;
  } else {
    return path_.IsPrefixOf(doc_path) && path_.size() == doc_path.size() - 1;
  }
}

bool Query::MatchesFilters(const Document& doc) const {
  return std::all_of(filters_.begin(), filters_.end(),
                     [&](const std::shared_ptr<core::Filter>& filter) {
                       return filter->Matches(doc);
                     });
}

bool Query::MatchesOrderBy(const Document&) const {
  // TODO(rsgowman): Implement this correctly.
  return true;
}

bool Query::MatchesBounds(const Document&) const {
  // TODO(rsgowman): Implement this correctly.
  return true;
}

Query Query::Filter(std::shared_ptr<core::Filter> filter) const {
  HARD_ASSERT(!DocumentKey::IsDocumentKey(path_),
              "No filter is allowed for document query");

  // TODO(rsgowman): ensure only one inequality field
  // TODO(rsgowman): ensure first orderby must match inequality field

  std::vector<std::shared_ptr<core::Filter>> updated_filters = filters_;
  updated_filters.push_back(std::move(filter));
  return Query(path_, std::move(updated_filters));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
