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

#import <XCTest/XCTest.h>

#include <vector>

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace core = firebase::firestore::core;
namespace testutil = firebase::firestore::testutil;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::DocumentViewChangeSet;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::testutil::Query;

using testutil::Doc;
using testutil::Map;

NS_ASSUME_NONNULL_BEGIN

@interface FSTViewSnapshotTests : XCTestCase
@end

@implementation FSTViewSnapshotTests

- (void)testDocumentChangeConstructor {
  Document doc = Doc("a/b", 0, Map());
  DocumentViewChange::Type type = DocumentViewChange::Type::Modified;
  DocumentViewChange change{doc, type};
  XCTAssertEqual(change.document(), doc);
  XCTAssertEqual(change.type(), type);
}

- (void)testTrack {
  DocumentViewChangeSet set;

  Document docAdded = Doc("a/1", 0, Map());
  Document docRemoved = Doc("a/2", 0, Map());
  Document docModified = Doc("a/3", 0, Map());

  Document docAddedThenModified = Doc("b/1", 0, Map());
  Document docAddedThenRemoved = Doc("b/2", 0, Map());
  Document docRemovedThenAdded = Doc("b/3", 0, Map());
  Document docModifiedThenRemoved = Doc("b/4", 0, Map());
  Document docModifiedThenModified = Doc("b/5", 0, Map());

  set.AddChange(DocumentViewChange{docAdded, DocumentViewChange::Type::Added});
  set.AddChange(DocumentViewChange{docRemoved, DocumentViewChange::Type::Removed});
  set.AddChange(DocumentViewChange{docModified, DocumentViewChange::Type::Modified});
  set.AddChange(DocumentViewChange{docAddedThenModified, DocumentViewChange::Type::Added});
  set.AddChange(DocumentViewChange{docAddedThenModified, DocumentViewChange::Type::Modified});
  set.AddChange(DocumentViewChange{docAddedThenRemoved, DocumentViewChange::Type::Added});
  set.AddChange(DocumentViewChange{docAddedThenRemoved, DocumentViewChange::Type::Removed});
  set.AddChange(DocumentViewChange{docRemovedThenAdded, DocumentViewChange::Type::Removed});
  set.AddChange(DocumentViewChange{docRemovedThenAdded, DocumentViewChange::Type::Added});
  set.AddChange(DocumentViewChange{docModifiedThenRemoved, DocumentViewChange::Type::Modified});
  set.AddChange(DocumentViewChange{docModifiedThenRemoved, DocumentViewChange::Type::Removed});
  set.AddChange(DocumentViewChange{docModifiedThenModified, DocumentViewChange::Type::Modified});
  set.AddChange(DocumentViewChange{docModifiedThenModified, DocumentViewChange::Type::Modified});

  std::vector<DocumentViewChange> changes = set.GetChanges();
  XCTAssertEqual(changes.size(), 7);

  XCTAssertEqual(changes[0].document(), docAdded);
  XCTAssertEqual(changes[0].type(), DocumentViewChange::Type::Added);

  XCTAssertEqual(changes[1].document(), docRemoved);
  XCTAssertEqual(changes[1].type(), DocumentViewChange::Type::Removed);

  XCTAssertEqual(changes[2].document(), docModified);
  XCTAssertEqual(changes[2].type(), DocumentViewChange::Type::Modified);

  XCTAssertEqual(changes[3].document(), docAddedThenModified);
  XCTAssertEqual(changes[3].type(), DocumentViewChange::Type::Added);

  XCTAssertEqual(changes[4].document(), docRemovedThenAdded);
  XCTAssertEqual(changes[4].type(), DocumentViewChange::Type::Modified);

  XCTAssertEqual(changes[5].document(), docModifiedThenRemoved);
  XCTAssertEqual(changes[5].type(), DocumentViewChange::Type::Removed);

  XCTAssertEqual(changes[6].document(), docModifiedThenModified);
  XCTAssertEqual(changes[6].type(), DocumentViewChange::Type::Modified);
}

- (void)testViewSnapshotConstructor {
  core::Query query = Query("a");
  DocumentSet documents = DocumentSet{DocumentComparator::ByKey()};
  DocumentSet oldDocuments = documents;
  documents = documents.insert(Doc("c/a", 1, Map()));
  std::vector<DocumentViewChange> documentChanges{
      DocumentViewChange{Doc("c/a", 1, Map()), DocumentViewChange::Type::Added}};

  bool fromCache = true;
  DocumentKeySet mutatedKeys;
  bool syncStateChanged = true;

  ViewSnapshot snapshot{query,
                        documents,
                        oldDocuments,
                        documentChanges,
                        mutatedKeys,
                        fromCache,
                        syncStateChanged,
                        /*excludes_metadata_changes=*/false};

  XCTAssertEqual(snapshot.query(), query);
  XCTAssertEqual(snapshot.documents(), documents);
  XCTAssertEqual(snapshot.old_documents(), oldDocuments);
  XCTAssertEqual(snapshot.document_changes(), documentChanges);
  XCTAssertEqual(snapshot.from_cache(), fromCache);
  XCTAssertEqual(snapshot.mutated_keys(), mutatedKeys);
  XCTAssertEqual(snapshot.sync_state_changed(), syncStateChanged);
}

@end

NS_ASSUME_NONNULL_END
