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

#include "Firestore/core/src/core/view_snapshot.h"

#include <vector>

#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using model::DocumentComparator;
using model::DocumentKeySet;
using model::DocumentSet;
using model::MutableDocument;

using testutil::Doc;
using testutil::Map;

using Type = DocumentViewChange::Type;

TEST(ViewSnapshotTest, DocumentChangeConstructor) {
  MutableDocument doc = Doc("a/b", 0, Map());
  Type type = Type::Modified;
  DocumentViewChange change{doc, type};
  ASSERT_EQ(change.document(), doc);
  ASSERT_EQ(change.type(), type);
}

TEST(ViewSnapshotTest, Track) {
  DocumentViewChangeSet set;

  MutableDocument doc_added = Doc("a/1", 0, Map());
  MutableDocument doc_removed = Doc("a/2", 0, Map());
  MutableDocument doc_modified = Doc("a/3", 0, Map());

  MutableDocument doc_added_then_modified = Doc("b/1", 0, Map());
  MutableDocument doc_added_then_removed = Doc("b/2", 0, Map());
  MutableDocument doc_removed_then_added = Doc("b/3", 0, Map());
  MutableDocument doc_modified_then_removed = Doc("b/4", 0, Map());
  MutableDocument doc_modified_then_modified = Doc("b/5", 0, Map());

  set.AddChange(DocumentViewChange{doc_added, Type::Added});
  set.AddChange(DocumentViewChange{doc_removed, Type::Removed});
  set.AddChange(DocumentViewChange{doc_modified, Type::Modified});
  set.AddChange(DocumentViewChange{doc_added_then_modified, Type::Added});
  set.AddChange(DocumentViewChange{doc_added_then_modified, Type::Modified});
  set.AddChange(DocumentViewChange{doc_added_then_removed, Type::Added});
  set.AddChange(DocumentViewChange{doc_added_then_removed, Type::Removed});
  set.AddChange(DocumentViewChange{doc_removed_then_added, Type::Removed});
  set.AddChange(DocumentViewChange{doc_removed_then_added, Type::Added});
  set.AddChange(DocumentViewChange{doc_modified_then_removed, Type::Modified});
  set.AddChange(DocumentViewChange{doc_modified_then_removed, Type::Removed});
  set.AddChange(DocumentViewChange{doc_modified_then_modified, Type::Modified});
  set.AddChange(DocumentViewChange{doc_modified_then_modified, Type::Modified});

  std::vector<DocumentViewChange> changes = set.GetChanges();
  ASSERT_EQ(changes.size(), 7);

  ASSERT_EQ(changes[0].document(), doc_added);
  ASSERT_EQ(changes[0].type(), Type::Added);

  ASSERT_EQ(changes[1].document(), doc_removed);
  ASSERT_EQ(changes[1].type(), Type::Removed);

  ASSERT_EQ(changes[2].document(), doc_modified);
  ASSERT_EQ(changes[2].type(), Type::Modified);

  ASSERT_EQ(changes[3].document(), doc_added_then_modified);
  ASSERT_EQ(changes[3].type(), Type::Added);

  ASSERT_EQ(changes[4].document(), doc_removed_then_added);
  ASSERT_EQ(changes[4].type(), Type::Modified);

  ASSERT_EQ(changes[5].document(), doc_modified_then_removed);
  ASSERT_EQ(changes[5].type(), Type::Removed);

  ASSERT_EQ(changes[6].document(), doc_modified_then_modified);
  ASSERT_EQ(changes[6].type(), Type::Modified);
}

TEST(ViewSnapshotTest, ViewSnapshotConstructor) {
  Query query = testutil::Query("a");
  DocumentSet documents = DocumentSet{DocumentComparator::ByKey()};
  DocumentSet old_documents = documents;
  documents = documents.insert(Doc("c/a", 1, Map()));
  std::vector<DocumentViewChange> document_changes{
      DocumentViewChange{Doc("c/a", 1, Map()), Type::Added}};

  bool from_cache = true;
  DocumentKeySet mutated_keys;
  bool sync_state_changed = true;
  bool has_cached_results = true;

  ViewSnapshot snapshot{query,
                        documents,
                        old_documents,
                        document_changes,
                        mutated_keys,
                        from_cache,
                        sync_state_changed,
                        /*excludes_metadata_changes=*/false,
                        has_cached_results};

  ASSERT_EQ(snapshot.query(), query);
  ASSERT_EQ(snapshot.documents(), documents);
  ASSERT_EQ(snapshot.old_documents(), old_documents);
  ASSERT_EQ(snapshot.document_changes(), document_changes);
  ASSERT_EQ(snapshot.from_cache(), from_cache);
  ASSERT_EQ(snapshot.mutated_keys(), mutated_keys);
  ASSERT_EQ(snapshot.sync_state_changed(), sync_state_changed);
  ASSERT_EQ(snapshot.has_cached_results(), has_cached_results);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
