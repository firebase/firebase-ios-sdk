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

#import "Firestore/Source/Core/FSTViewSnapshot.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTViewSnapshotTests : XCTestCase
@end

@implementation FSTViewSnapshotTests

- (void)testDocumentChangeConstructor {
  FSTDocument *doc = FSTTestDoc(@"a/b", 0, @{}, NO);
  FSTDocumentViewChangeType type = FSTDocumentViewChangeTypeModified;
  FSTDocumentViewChange *change = [FSTDocumentViewChange changeWithDocument:doc type:type];
  XCTAssertEqual(change.document, doc);
  XCTAssertEqual(change.type, type);
}

- (void)testTrack {
  FSTDocumentViewChangeSet *set = [FSTDocumentViewChangeSet changeSet];

  FSTDocument *docAdded = FSTTestDoc(@"a/1", 0, @{}, NO);
  FSTDocument *docRemoved = FSTTestDoc(@"a/2", 0, @{}, NO);
  FSTDocument *docModified = FSTTestDoc(@"a/3", 0, @{}, NO);

  FSTDocument *docAddedThenModified = FSTTestDoc(@"b/1", 0, @{}, NO);
  FSTDocument *docAddedThenRemoved = FSTTestDoc(@"b/2", 0, @{}, NO);
  FSTDocument *docRemovedThenAdded = FSTTestDoc(@"b/3", 0, @{}, NO);
  FSTDocument *docModifiedThenRemoved = FSTTestDoc(@"b/4", 0, @{}, NO);
  FSTDocument *docModifiedThenModified = FSTTestDoc(@"b/5", 0, @{}, NO);

  [set addChange:[FSTDocumentViewChange changeWithDocument:docAdded
                                                      type:FSTDocumentViewChangeTypeAdded]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docRemoved
                                                      type:FSTDocumentViewChangeTypeRemoved]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docModified
                                                      type:FSTDocumentViewChangeTypeModified]];

  [set addChange:[FSTDocumentViewChange changeWithDocument:docAddedThenModified
                                                      type:FSTDocumentViewChangeTypeAdded]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docAddedThenModified
                                                      type:FSTDocumentViewChangeTypeModified]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docAddedThenRemoved
                                                      type:FSTDocumentViewChangeTypeAdded]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docAddedThenRemoved
                                                      type:FSTDocumentViewChangeTypeRemoved]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docRemovedThenAdded
                                                      type:FSTDocumentViewChangeTypeRemoved]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docRemovedThenAdded
                                                      type:FSTDocumentViewChangeTypeAdded]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docModifiedThenRemoved
                                                      type:FSTDocumentViewChangeTypeModified]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docModifiedThenRemoved
                                                      type:FSTDocumentViewChangeTypeRemoved]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docModifiedThenModified
                                                      type:FSTDocumentViewChangeTypeModified]];
  [set addChange:[FSTDocumentViewChange changeWithDocument:docModifiedThenModified
                                                      type:FSTDocumentViewChangeTypeModified]];

  NSArray<FSTDocumentViewChange *> *changes = [set changes];
  XCTAssertEqual(changes.count, 7);

  XCTAssertEqual(changes[0].document, docAdded);
  XCTAssertEqual(changes[0].type, FSTDocumentViewChangeTypeAdded);

  XCTAssertEqual(changes[1].document, docRemoved);
  XCTAssertEqual(changes[1].type, FSTDocumentViewChangeTypeRemoved);

  XCTAssertEqual(changes[2].document, docModified);
  XCTAssertEqual(changes[2].type, FSTDocumentViewChangeTypeModified);

  XCTAssertEqual(changes[3].document, docAddedThenModified);
  XCTAssertEqual(changes[3].type, FSTDocumentViewChangeTypeAdded);

  XCTAssertEqual(changes[4].document, docRemovedThenAdded);
  XCTAssertEqual(changes[4].type, FSTDocumentViewChangeTypeModified);

  XCTAssertEqual(changes[5].document, docModifiedThenRemoved);
  XCTAssertEqual(changes[5].type, FSTDocumentViewChangeTypeRemoved);

  XCTAssertEqual(changes[6].document, docModifiedThenModified);
  XCTAssertEqual(changes[6].type, FSTDocumentViewChangeTypeModified);
}

- (void)testViewSnapshotConstructor {
  FSTQuery *query = [FSTQuery queryWithPath:[FSTResourcePath pathWithSegments:@[ @"a" ]]];
  FSTDocumentSet *documents = [FSTDocumentSet documentSetWithComparator:FSTDocumentComparatorByKey];
  FSTDocumentSet *oldDocuments = documents;
  documents = [documents documentSetByAddingDocument:FSTTestDoc(@"c/a", 1, @{}, NO)];
  NSArray<FSTDocumentViewChange *> *documentChanges =
      @[ [FSTDocumentViewChange changeWithDocument:FSTTestDoc(@"c/a", 1, @{}, NO)
                                              type:FSTDocumentViewChangeTypeAdded] ];

  BOOL fromCache = YES;
  BOOL hasPendingWrites = NO;
  BOOL syncStateChanged = YES;

  FSTViewSnapshot *snapshot = [[FSTViewSnapshot alloc] initWithQuery:query
                                                           documents:documents
                                                        oldDocuments:oldDocuments
                                                     documentChanges:documentChanges
                                                           fromCache:fromCache
                                                    hasPendingWrites:hasPendingWrites
                                                    syncStateChanged:syncStateChanged];

  XCTAssertEqual(snapshot.query, query);
  XCTAssertEqual(snapshot.documents, documents);
  XCTAssertEqual(snapshot.oldDocuments, oldDocuments);
  XCTAssertEqual(snapshot.documentChanges, documentChanges);
  XCTAssertEqual(snapshot.fromCache, fromCache);
  XCTAssertEqual(snapshot.hasPendingWrites, hasPendingWrites);
  XCTAssertEqual(snapshot.syncStateChanged, syncStateChanged);
}

@end

NS_ASSUME_NONNULL_END
