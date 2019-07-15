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

#import "Firestore/Source/Local/FSTLocalStore.h"

#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#include <utility>
#include <vector>

#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLocalWriteResult.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Util/FSTClasses.h"

#import "Firestore/Example/Tests/Local/FSTLocalStoreTests.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/third_party/Immutable/Tests/FSTImmutableSortedDictionary+Testing.h"
#import "Firestore/third_party/Immutable/Tests/FSTImmutableSortedSet+Testing.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::auth::User;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::TestTargetMetadataProvider;
using firebase::firestore::remote::WatchChangeAggregator;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::util::Status;

static NSArray<FSTDocument *> *docMapToArray(const DocumentMap &docs) {
  NSMutableArray<FSTDocument *> *result = [NSMutableArray array];
  for (const auto &kv : docs.underlying_map()) {
    [result addObject:static_cast<FSTDocument *>(kv.second)];
  }
  return result;
}

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalStoreTests ()

@property(nonatomic, strong, readwrite) id<FSTPersistence> localStorePersistence;
@property(nonatomic, strong, readwrite) FSTLocalStore *localStore;

@property(nonatomic, strong, readonly) NSMutableArray<FSTMutationBatch *> *batches;
@property(nonatomic, assign, readwrite) TargetId lastTargetID;

@end

@implementation FSTLocalStoreTests {
  MaybeDocumentMap _lastChanges;
}

- (void)setUp {
  [super setUp];

  if ([self isTestBaseClass]) {
    return;
  }

  id<FSTPersistence> persistence = [self persistence];
  self.localStorePersistence = persistence;
  self.localStore = [[FSTLocalStore alloc] initWithPersistence:persistence
                                                   initialUser:User::Unauthenticated()];
  [self.localStore start];

  _batches = [NSMutableArray array];
  _lastTargetID = 0;
}

- (void)tearDown {
  [self.localStorePersistence shutdown];

  [super tearDown];
}

- (id<FSTPersistence>)persistence {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)gcIsEager {
  @throw FSTAbstractMethodException();  // NOLINT
}

/**
 * Xcode will run tests from any class that extends XCTestCase, but this doesn't work for
 * FSTLocalStoreTests since it is incomplete without the implementations supplied by its
 * subclasses.
 */
- (BOOL)isTestBaseClass {
  return [self class] == [FSTLocalStoreTests class];
}

- (void)writeMutation:(FSTMutation *)mutation {
  [self writeMutations:{mutation}];
}

- (void)writeMutations:(std::vector<FSTMutation *> &&)mutations {
  auto mutationsCopy = mutations;
  FSTLocalWriteResult *result = [self.localStore locallyWriteMutations:std::move(mutationsCopy)];
  XCTAssertNotNil(result);
  [self.batches addObject:[[FSTMutationBatch alloc] initWithBatchID:result.batchID
                                                     localWriteTime:Timestamp::Now()
                                                      baseMutations:{}
                                                          mutations:std::move(mutations)]];
  _lastChanges = result.changes;
}

- (void)applyRemoteEvent:(const RemoteEvent &)event {
  _lastChanges = [self.localStore applyRemoteEvent:event];
}

- (void)notifyLocalViewChanges:(FSTLocalViewChanges *)changes {
  [self.localStore notifyLocalViewChanges:@[ changes ]];
}

- (void)acknowledgeMutationWithVersion:(FSTTestSnapshotVersion)documentVersion
                       transformResult:(id _Nullable)transformResult {
  FSTMutationBatch *batch = [self.batches firstObject];
  [self.batches removeObjectAtIndex:0];
  XCTAssertEqual(batch.mutations.size(), 1, @"Acknowledging more than one mutation not supported.");
  SnapshotVersion version = testutil::Version(documentVersion);

  absl::optional<std::vector<FieldValue>> mutationTransformResult;
  if (transformResult) {
    mutationTransformResult = std::vector<FieldValue>{FSTTestFieldValue(transformResult)};
  }

  FSTMutationResult *mutationResult =
      [[FSTMutationResult alloc] initWithVersion:version transformResults:mutationTransformResult];
  FSTMutationBatchResult *result = [FSTMutationBatchResult resultWithBatch:batch
                                                             commitVersion:version
                                                           mutationResults:{mutationResult}
                                                               streamToken:nil];
  _lastChanges = [self.localStore acknowledgeBatchWithResult:result];
}

- (void)acknowledgeMutationWithVersion:(FSTTestSnapshotVersion)documentVersion {
  [self acknowledgeMutationWithVersion:documentVersion transformResult:nil];
}

- (void)rejectMutation {
  FSTMutationBatch *batch = [self.batches firstObject];
  [self.batches removeObjectAtIndex:0];
  _lastChanges = [self.localStore rejectBatchID:batch.batchID];
}

- (TargetId)allocateQuery:(FSTQuery *)query {
  FSTQueryData *queryData = [self.localStore allocateQuery:query];
  self.lastTargetID = queryData.targetID;
  return queryData.targetID;
}

/** Asserts that the last target ID is the given number. */
#define FSTAssertTargetID(targetID)              \
  do {                                           \
    XCTAssertEqual(self.lastTargetID, targetID); \
  } while (0)

/** Asserts that a the lastChanges contain the docs in the given array. */
#define FSTAssertChanged(documents)                                           \
  do {                                                                        \
    NSArray<FSTMaybeDocument *> *expected = (documents);                      \
    XCTAssertEqual(_lastChanges.size(), expected.count);                      \
    NSEnumerator<FSTMaybeDocument *> *enumerator = expected.objectEnumerator; \
    for (const auto &kv : _lastChanges) {                                     \
      FSTMaybeDocument *value = kv.second;                                    \
      XCTAssertEqualObjects(value, [enumerator nextObject]);                  \
    }                                                                         \
    _lastChanges = MaybeDocumentMap{};                                        \
  } while (0)

/** Asserts that the given keys were removed. */
#define FSTAssertRemoved(keyPaths)                                             \
  do {                                                                         \
    XCTAssertEqual(_lastChanges.size(), keyPaths.count);                       \
    NSEnumerator<NSString *> *keyPathEnumerator = keyPaths.objectEnumerator;   \
    for (const auto &kv : _lastChanges) {                                      \
      const DocumentKey &actualKey = kv.first;                                 \
      FSTMaybeDocument *value = kv.second;                                     \
      DocumentKey expectedKey = FSTTestDocKey([keyPathEnumerator nextObject]); \
      XCTAssertEqual(actualKey, expectedKey);                                  \
      XCTAssertTrue([value isKindOfClass:[FSTDeletedDocument class]]);         \
    }                                                                          \
    _lastChanges = MaybeDocumentMap{};                                         \
  } while (0)

/** Asserts that the given local store contains the given document. */
#define FSTAssertContains(document)                                         \
  do {                                                                      \
    FSTMaybeDocument *expected = (document);                                \
    FSTMaybeDocument *actual = [self.localStore readDocument:expected.key]; \
    XCTAssertEqualObjects(actual, expected);                                \
  } while (0)

/** Asserts that the given local store does not contain the given document. */
#define FSTAssertNotContains(keyPathString)                        \
  do {                                                             \
    DocumentKey key = FSTTestDocKey(keyPathString);                \
    FSTMaybeDocument *actual = [self.localStore readDocument:key]; \
    XCTAssertNil(actual);                                          \
  } while (0)

- (void)testMutationBatchKeys {
  if ([self isTestBaseClass]) return;

  FSTMutation *base = FSTTestSetMutation(@"foo/ignore", @{@"foo" : @"bar"});
  FSTMutation *set1 = FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"});
  FSTMutation *set2 = FSTTestSetMutation(@"bar/baz", @{@"bar" : @"baz"});
  FSTMutationBatch *batch = [[FSTMutationBatch alloc] initWithBatchID:1
                                                       localWriteTime:Timestamp::Now()
                                                        baseMutations:{base}
                                                            mutations:{set1, set2}];
  DocumentKeySet keys = [batch keys];
  XCTAssertEqual(keys.size(), 2u);
}

- (void)testHandlesSetMutation {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:0];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations) ]);
  if ([self gcIsEager]) {
    // Nothing is pinning this anymore, as it has been acknowledged and there are no targets active.
    FSTAssertNotContains(@"foo/bar");
  } else {
    FSTAssertContains(
        FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations));
  }
}

- (void)testHandlesSetMutationThenDocument {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(FSTTestDoc("foo/bar", 2, @{@"it" : @"changed"},
                                                             DocumentState::kSynced),
                                                  {targetID}, {})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
}

- (void)testHandlesAckThenRejectThenRemoteEvent {
  if ([self isTestBaseClass]) return;

  // Start a query that requires acks to be held.
  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  // The last seen version is zero, so this ack must be held.
  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations) ]);

  // Under eager GC, there is no longer a reference for the document, and it should be
  // deleted.
  if ([self gcIsEager]) {
    FSTAssertNotContains(@"foo/bar");
  } else {
    FSTAssertContains(
        FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations));
  }

  [self writeMutation:FSTTestSetMutation(@"bar/baz", @{@"bar" : @"baz"})];
  FSTAssertChanged(
      @[ FSTTestDoc("bar/baz", 0, @{@"bar" : @"baz"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("bar/baz", 0, @{@"bar" : @"baz"}, DocumentState::kLocalMutations));

  [self rejectMutation];
  FSTAssertRemoved(@[ @"bar/baz" ]);
  FSTAssertNotContains(@"bar/baz");

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(FSTTestDoc("foo/bar", 2, @{@"it" : @"changed"},
                                                            DocumentState::kSynced),
                                                 {targetID})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 2, @{@"it" : @"changed"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"it" : @"changed"}, DocumentState::kSynced));
  FSTAssertNotContains(@"bar/baz");
}

- (void)testHandlesDeletedDocumentThenSetMutationThenAck {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(FSTTestDeletedDoc("foo/bar", 2, NO), {targetID},
                                                  {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  // Under eager GC, there is no longer a reference for the document, and it should be
  // deleted.
  if (![self gcIsEager]) {
    FSTAssertContains(FSTTestDeletedDoc("foo/bar", 2, NO));
  } else {
    FSTAssertNotContains(@"foo/bar");
  }

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
  // Can now remove the target, since we have a mutation pinning the document
  [self.localStore releaseQuery:query];
  // Verify we didn't lose anything
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 3, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations) ]);
  // It has been acknowledged, and should no longer be retained as there is no target and mutation
  if ([self gcIsEager]) {
    FSTAssertNotContains(@"foo/bar");
  }
}

- (void)testHandlesSetMutationThenDeletedDocument {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(FSTTestDeletedDoc("foo/bar", 2, NO), {targetID},
                                                  {})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
}

- (void)testHandlesDocumentThenSetMutationThenAckThenDocument {
  if ([self isTestBaseClass]) return;

  // Start a query that requires acks to be held.
  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 2, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 2, @{@"it" : @"base"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"it" : @"base"}, DocumentState::kSynced));

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3];
  // we haven't seen the remote event yet, so the write is still held.
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 3, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations) ]);
  FSTAssertContains(
      FSTTestDoc("foo/bar", 3, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(FSTTestDoc("foo/bar", 3, @{@"it" : @"changed"},
                                                             DocumentState::kSynced),
                                                  {targetID}, {})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 3, @{@"it" : @"changed"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 3, @{@"it" : @"changed"}, DocumentState::kSynced));
}

- (void)testHandlesPatchWithoutPriorDocument {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertNotContains(@"foo/bar");

  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(@[ FSTTestUnknownDoc("foo/bar", 1) ]);
  if ([self gcIsEager]) {
    FSTAssertNotContains(@"foo/bar");
  } else {
    FSTAssertContains(FSTTestUnknownDoc("foo/bar", 1));
  }
}

- (void)testHandlesPatchMutationThenDocumentThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertNotContains(@"foo/bar");

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar", @"it" : @"base"},
                                 DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar", @"it" : @"base"},
                               DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:2];
  // We still haven't seen the remote events for the patch, so the local changes remain, and there
  // are no changes
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar", @"it" : @"base"},
                                 DocumentState::kCommittedMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar", @"it" : @"base"},
                               DocumentState::kCommittedMutations));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar", @"it" : @"base"},
                                        DocumentState::kSynced),
                             {targetID}, {})];

  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar", @"it" : @"base"}, DocumentState::kSynced) ]);
  FSTAssertContains(
      FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar", @"it" : @"base"}, DocumentState::kSynced));
}

- (void)testHandlesPatchMutationThenAckThenDocument {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertNotContains(@"foo/bar");

  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(@[ FSTTestUnknownDoc("foo/bar", 1) ]);

  // There's no target pinning the doc, and we've ack'd the mutation.
  if ([self gcIsEager]) {
    FSTAssertNotContains(@"foo/bar");
  } else {
    FSTAssertContains(FSTTestUnknownDoc("foo/bar", 1));
  }

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID}, {})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced));
}

- (void)testHandlesDeleteMutationThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 0, NO));

  [self acknowledgeMutationWithVersion:1];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  // There's no target pinning the doc, and we've ack'd the mutation.
  if ([self gcIsEager]) {
    FSTAssertNotContains(@"foo/bar");
  }
}

- (void)testHandlesDocumentThenDeleteMutationThenAck {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID}, {})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced));

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 0, NO));

  // Remove the target so only the mutation is pinning the document
  [self.localStore releaseQuery:query];

  [self acknowledgeMutationWithVersion:2];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  if ([self gcIsEager]) {
    // Neither the target nor the mutation pin the document, it should be gone.
    FSTAssertNotContains(@"foo/bar");
  }
}

- (void)testHandlesDeleteMutationThenDocumentThenAck {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 0, NO));

  // Add the document to a target so it will remain in persistence even when ack'd
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID}, {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 0, NO));

  // Don't need to keep it pinned anymore
  [self.localStore releaseQuery:query];

  [self acknowledgeMutationWithVersion:2];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  if ([self gcIsEager]) {
    // The doc is not pinned in a target and we've acknowledged the mutation. It shouldn't exist
    // anymore.
    FSTAssertNotContains(@"foo/bar");
  }
}

- (void)testHandlesDocumentThenDeletedDocumentThenDocument {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID}, {})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(FSTTestDeletedDoc("foo/bar", 2, NO), {targetID},
                                                  {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  if (![self gcIsEager]) {
    FSTAssertContains(FSTTestDeletedDoc("foo/bar", 2, NO));
  }

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(FSTTestDoc("foo/bar", 3, @{@"it" : @"changed"},
                                                             DocumentState::kSynced),
                                                  {targetID}, {})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 3, @{@"it" : @"changed"}, DocumentState::kSynced) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 3, @{@"it" : @"changed"}, DocumentState::kSynced));
}

- (void)testHandlesSetMutationThenPatchMutationThenDocumentThenAckThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"old"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"old"}, DocumentState::kLocalMutations));

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"it" : @"base"}, DocumentState::kSynced),
                             {targetID}, {})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  [self.localStore releaseQuery:query];
  [self acknowledgeMutationWithVersion:2];  // delete mutation
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3];  // patch mutation
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 3, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations) ]);
  if ([self gcIsEager]) {
    // we've ack'd all of the mutations, nothing is keeping this pinned anymore
    FSTAssertNotContains(@"foo/bar");
  } else {
    FSTAssertContains(
        FSTTestDoc("foo/bar", 3, @{@"foo" : @"bar"}, DocumentState::kCommittedMutations));
  }
}

- (void)testHandlesSetMutationAndPatchMutationTogether {
  if ([self isTestBaseClass]) return;

  [self writeMutations:{
    FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"}),
        FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})
  }];

  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations) ]);
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
}

- (void)testHandlesSetMutationThenPatchMutationThenReject {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"})];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"old"}, DocumentState::kLocalMutations));
  [self acknowledgeMutationWithVersion:1];
  FSTAssertNotContains(@"foo/bar");

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  // A blind patch is not visible in the cache
  FSTAssertNotContains(@"foo/bar");

  [self rejectMutation];
  FSTAssertNotContains(@"foo/bar");
}

- (void)testHandlesSetMutationsAndPatchMutationOfJustOneTogether {
  if ([self isTestBaseClass]) return;

  [self writeMutations:{
    FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"}),
        FSTTestSetMutation(@"bar/baz", @{@"bar" : @"baz"}),
        FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})
  }];

  FSTAssertChanged((@[
    FSTTestDoc("bar/baz", 0, @{@"bar" : @"baz"}, DocumentState::kLocalMutations),
    FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations)
  ]));
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDoc("bar/baz", 0, @{@"bar" : @"baz"}, DocumentState::kLocalMutations));
}

- (void)testHandlesDeleteMutationThenPatchMutationThenAckThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 0, NO));

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 0, NO));

  [self acknowledgeMutationWithVersion:2];  // delete mutation
  FSTAssertRemoved(@[ @"foo/bar" ]);
  FSTAssertContains(FSTTestDeletedDoc("foo/bar", 2, YES));

  [self acknowledgeMutationWithVersion:3];  // patch mutation
  FSTAssertChanged(@[ FSTTestUnknownDoc("foo/bar", 3) ]);
  if ([self gcIsEager]) {
    // There are no more pending mutations, the doc has been dropped
    FSTAssertNotContains(@"foo/bar");
  } else {
    FSTAssertContains(FSTTestUnknownDoc("foo/bar", 3));
  }
}

- (void)testCollectsGarbageAfterChangeBatchWithNoTargetIDs {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  [self applyRemoteEvent:FSTTestUpdateRemoteEventWithLimboTargets(
                             FSTTestDeletedDoc("foo/bar", 2, NO), {}, {}, {1})];
  FSTAssertNotContains(@"foo/bar");

  [self applyRemoteEvent:FSTTestUpdateRemoteEventWithLimboTargets(
                             FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kSynced),
                             {}, {}, {1})];
  FSTAssertNotContains(@"foo/bar");
}

- (void)testCollectsGarbageAfterChangeBatch {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kSynced),
                             {targetID})];
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"foo" : @"bar"}, DocumentState::kSynced));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 2, @{@"foo" : @"baz"}, DocumentState::kSynced),
                             {}, {targetID})];

  FSTAssertNotContains(@"foo/bar");
}

- (void)testCollectsGarbageAfterAcknowledgedMutation {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 0, @{@"foo" : @"old"}, DocumentState::kSynced),
                             {targetID}, {})];
  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  // Release the query so that our target count goes back to 0 and we are considered up-to-date.
  [self.localStore releaseQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bah", @{@"foo" : @"bah"})];
  [self writeMutation:FSTTestDeleteMutation(@"foo/baz")];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDoc("foo/bah", 0, @{@"foo" : @"bah"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDeletedDoc("foo/baz", 0, NO));

  [self acknowledgeMutationWithVersion:3];
  FSTAssertNotContains(@"foo/bar");
  FSTAssertContains(FSTTestDoc("foo/bah", 0, @{@"foo" : @"bah"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDeletedDoc("foo/baz", 0, NO));

  [self acknowledgeMutationWithVersion:4];
  FSTAssertNotContains(@"foo/bar");
  FSTAssertNotContains(@"foo/bah");
  FSTAssertContains(FSTTestDeletedDoc("foo/baz", 0, NO));

  [self acknowledgeMutationWithVersion:5];
  FSTAssertNotContains(@"foo/bar");
  FSTAssertNotContains(@"foo/bah");
  FSTAssertNotContains(@"foo/baz");
}

- (void)testCollectsGarbageAfterRejectedMutation {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 0, @{@"foo" : @"old"}, DocumentState::kSynced),
                             {targetID}, {})];
  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  // Release the query so that our target count goes back to 0 and we are considered up-to-date.
  [self.localStore releaseQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bah", @{@"foo" : @"bah"})];
  [self writeMutation:FSTTestDeleteMutation(@"foo/baz")];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDoc("foo/bah", 0, @{@"foo" : @"bah"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDeletedDoc("foo/baz", 0, NO));

  [self rejectMutation];  // patch mutation
  FSTAssertNotContains(@"foo/bar");
  FSTAssertContains(FSTTestDoc("foo/bah", 0, @{@"foo" : @"bah"}, DocumentState::kLocalMutations));
  FSTAssertContains(FSTTestDeletedDoc("foo/baz", 0, NO));

  [self rejectMutation];  // set mutation
  FSTAssertNotContains(@"foo/bar");
  FSTAssertNotContains(@"foo/bah");
  FSTAssertContains(FSTTestDeletedDoc("foo/baz", 0, NO));

  [self rejectMutation];  // delete mutation
  FSTAssertNotContains(@"foo/bar");
  FSTAssertNotContains(@"foo/bah");
  FSTAssertNotContains(@"foo/baz");
}

- (void)testPinsDocumentsInTheLocalView {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  FSTQuery *query = FSTTestQuery("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kSynced),
                             {targetID})];
  [self writeMutation:FSTTestSetMutation(@"foo/baz", @{@"foo" : @"baz"})];
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kSynced));
  FSTAssertContains(FSTTestDoc("foo/baz", 0, @{@"foo" : @"baz"}, DocumentState::kLocalMutations));

  [self notifyLocalViewChanges:FSTTestViewChanges(targetID, @[ @"foo/bar", @"foo/baz" ], @[])];
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kSynced));
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kSynced),
                             {}, {targetID})];
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/baz", 2, @{@"foo" : @"baz"}, DocumentState::kSynced),
                             {targetID}, {})];
  FSTAssertContains(FSTTestDoc("foo/baz", 2, @{@"foo" : @"baz"}, DocumentState::kLocalMutations));
  [self acknowledgeMutationWithVersion:2];
  FSTAssertContains(FSTTestDoc("foo/baz", 2, @{@"foo" : @"baz"}, DocumentState::kSynced));
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"foo" : @"bar"}, DocumentState::kSynced));
  FSTAssertContains(FSTTestDoc("foo/baz", 2, @{@"foo" : @"baz"}, DocumentState::kSynced));

  [self notifyLocalViewChanges:FSTTestViewChanges(targetID, @[], @[ @"foo/bar", @"foo/baz" ])];
  [self.localStore releaseQuery:query];

  FSTAssertNotContains(@"foo/bar");
  FSTAssertNotContains(@"foo/baz");
}

- (void)testThrowsAwayDocumentsWithUnknownTargetIDsImmediately {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  TargetId targetID = 321;
  [self applyRemoteEvent:FSTTestUpdateRemoteEventWithLimboTargets(
                             FSTTestDoc("foo/bar", 1, @{}, DocumentState::kSynced), {}, {},
                             {targetID})];

  FSTAssertNotContains(@"foo/bar");
}

- (void)testCanExecuteDocumentQueries {
  if ([self isTestBaseClass]) return;

  [self.localStore locallyWriteMutations:{
    FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"}),
        FSTTestSetMutation(@"foo/baz", @{@"foo" : @"baz"}),
        FSTTestSetMutation(@"foo/bar/Foo/Bar", @{@"Foo" : @"Bar"})
  }];
  FSTQuery *query = FSTTestQuery("foo/bar");
  DocumentMap docs = [self.localStore executeQuery:query];
  XCTAssertEqualObjects(docMapToArray(docs), @[ FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"},
                                                           DocumentState::kLocalMutations) ]);
}

- (void)testCanExecuteCollectionQueries {
  if ([self isTestBaseClass]) return;

  [self.localStore locallyWriteMutations:{
    FSTTestSetMutation(@"fo/bar", @{@"fo" : @"bar"}),
        FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"}),
        FSTTestSetMutation(@"foo/baz", @{@"foo" : @"baz"}),
        FSTTestSetMutation(@"foo/bar/Foo/Bar", @{@"Foo" : @"Bar"}),
        FSTTestSetMutation(@"fooo/blah", @{@"fooo" : @"blah"})
  }];
  FSTQuery *query = FSTTestQuery("foo");
  DocumentMap docs = [self.localStore executeQuery:query];
  XCTAssertEqualObjects(
      docMapToArray(docs), (@[
        FSTTestDoc("foo/bar", 0, @{@"foo" : @"bar"}, DocumentState::kLocalMutations),
        FSTTestDoc("foo/baz", 0, @{@"foo" : @"baz"}, DocumentState::kLocalMutations)
      ]));
}

- (void)testCanExecuteMixedCollectionQueries {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/baz", 10, @{@"a" : @"b"}, DocumentState::kSynced), {2},
                             {})];
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 20, @{@"a" : @"b"}, DocumentState::kSynced), {2},
                             {})];

  [self.localStore locallyWriteMutations:{ FSTTestSetMutation(@"foo/bonk", @{@"a" : @"b"}) }];

  DocumentMap docs = [self.localStore executeQuery:query];
  XCTAssertEqualObjects(docMapToArray(docs), (@[
                          FSTTestDoc("foo/bar", 20, @{@"a" : @"b"}, DocumentState::kSynced),
                          FSTTestDoc("foo/baz", 10, @{@"a" : @"b"}, DocumentState::kSynced),
                          FSTTestDoc("foo/bonk", 0, @{@"a" : @"b"}, DocumentState::kLocalMutations)
                        ]));
}

- (void)testPersistsResumeTokens {
  if ([self isTestBaseClass]) return;
  // This test only works in the absence of the FSTEagerGarbageCollector.
  if ([self gcIsEager]) return;

  FSTQuery *query = FSTTestQuery("foo/bar");
  FSTQueryData *queryData = [self.localStore allocateQuery:query];
  ListenSequenceNumber initialSequenceNumber = queryData.sequenceNumber;
  TargetId targetID = queryData.targetID;
  NSData *resumeToken = FSTTestResumeTokenFromSnapshotVersion(1000);

  WatchTargetChange watchChange{WatchTargetChangeState::Current, {targetID}, resumeToken};
  auto metadataProvider = TestTargetMetadataProvider::CreateSingleResultProvider(
      testutil::Key("foo/bar"), std::vector<TargetId>{targetID});
  WatchChangeAggregator aggregator{&metadataProvider};
  aggregator.HandleTargetChange(watchChange);
  RemoteEvent remoteEvent = aggregator.CreateRemoteEvent(testutil::Version(1000));
  [self applyRemoteEvent:remoteEvent];

  // Stop listening so that the query should become inactive (but persistent)
  [self.localStore releaseQuery:query];

  // Should come back with the same resume token
  FSTQueryData *queryData2 = [self.localStore allocateQuery:query];
  XCTAssertEqualObjects(queryData2.resumeToken, resumeToken);

  // The sequence number should have been bumped when we saved the new resume token.
  ListenSequenceNumber newSequenceNumber = queryData2.sequenceNumber;
  XCTAssertGreaterThan(newSequenceNumber, initialSequenceNumber);
}

- (void)testRemoteDocumentKeysForTarget {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self
      applyRemoteEvent:FSTTestAddedRemoteEvent(
                           FSTTestDoc("foo/baz", 10, @{@"a" : @"b"}, DocumentState::kSynced), {2})];
  [self
      applyRemoteEvent:FSTTestAddedRemoteEvent(
                           FSTTestDoc("foo/bar", 20, @{@"a" : @"b"}, DocumentState::kSynced), {2})];

  [self.localStore locallyWriteMutations:{ FSTTestSetMutation(@"foo/bonk", @{@"a" : @"b"}) }];

  DocumentKeySet keys = [self.localStore remoteDocumentKeysForTarget:2];
  DocumentKeySet expected{testutil::Key("foo/bar"), testutil::Key("foo/baz")};
  XCTAssertEqual(keys, expected);

  keys = [self.localStore remoteDocumentKeysForTarget:2];
  XCTAssertEqual(keys, (DocumentKeySet{testutil::Key("foo/bar"), testutil::Key("foo/baz")}));
}

// TODO(mrschmidt): The FieldValue.increment() field transform tests below would probably be
// better implemented as spec tests but currently they don't support transforms.

- (void)testHandlesSetMutationThenTransformMutationThenTransformMutation {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0})];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"sum" : @0}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @0}, DocumentState::kLocalMutations) ]);

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]})];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"sum" : @3}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @3}, DocumentState::kLocalMutations) ]);
}

- (void)testHandlesSetMutationThenAckThenTransformMutationThenAckThenTransformMutation {
  if ([self isTestBaseClass]) return;

  // Since this test doesn't start a listen, Eager GC removes the documents from the cache as
  // soon as the mutation is applied. This creates a lot of special casing in this unit test but
  // does not expand its test coverage.
  if ([self gcIsEager]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0})];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"sum" : @0}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @0}, DocumentState::kLocalMutations) ]);

  [self acknowledgeMutationWithVersion:1];
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"sum" : @0}, DocumentState::kCommittedMutations));
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 1, @{@"sum" : @0}, DocumentState::kCommittedMutations) ]);

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})];
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);

  [self acknowledgeMutationWithVersion:2 transformResult:@1];
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"sum" : @1}, DocumentState::kCommittedMutations));
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 2, @{@"sum" : @1}, DocumentState::kCommittedMutations) ]);

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]})];
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"sum" : @3}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 2, @{@"sum" : @3}, DocumentState::kLocalMutations) ]);
}

- (void)testHandlesSetMutationThenTransformMutationThenRemoteEventThenTransformMutation {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0})];
  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"sum" : @0}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @0}, DocumentState::kLocalMutations) ]);

  [self
      applyRemoteEvent:FSTTestAddedRemoteEvent(
                           FSTTestDoc("foo/bar", 1, @{@"sum" : @0}, DocumentState::kSynced), {2})];

  [self acknowledgeMutationWithVersion:1];
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"sum" : @0}, DocumentState::kSynced));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @0}, DocumentState::kSynced) ]);

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})];
  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);

  // The value in this remote event gets ignored since we still have a pending transform mutation.
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             FSTTestDoc("foo/bar", 2, @{@"sum" : @0}, DocumentState::kSynced), {2},
                             {})];
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 2, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);

  // Add another increment. Note that we still compute the increment based on the local value.
  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]})];
  FSTAssertContains(FSTTestDoc("foo/bar", 2, @{@"sum" : @3}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 2, @{@"sum" : @3}, DocumentState::kLocalMutations) ]);

  [self acknowledgeMutationWithVersion:3 transformResult:@1];
  FSTAssertContains(FSTTestDoc("foo/bar", 3, @{@"sum" : @3}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 3, @{@"sum" : @3}, DocumentState::kLocalMutations) ]);

  [self acknowledgeMutationWithVersion:4 transformResult:@1339];
  FSTAssertContains(
      FSTTestDoc("foo/bar", 4, @{@"sum" : @1339}, DocumentState::kCommittedMutations));
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 4, @{@"sum" : @1339}, DocumentState::kCommittedMutations) ]);
}

- (void)testHoldsBackOnlyNonIdempotentTransforms {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0, @"array_union" : @[]})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @0, @"array_union" : @[]},
                                 DocumentState::kLocalMutations) ]);

  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @0, @"array_union" : @[]},
                                 DocumentState::kCommittedMutations) ]);

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"sum" : @0, @"array_union" : @[]},
                                        DocumentState::kSynced),
                             {2})];
  FSTAssertChanged(
      @[ FSTTestDoc("foo/bar", 1, @{@"sum" : @0, @"array_union" : @[]}, DocumentState::kSynced) ]);

  [self writeMutations:{
    FSTTestTransformMutation(@"foo/bar",
                             @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}),
        FSTTestTransformMutation(
            @"foo/bar",
            @{@"array_union" : [FIRFieldValue fieldValueForArrayUnion:@[ @"foo" ]]})
  }];

  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @1, @"array_union" : @[ @"foo" ]},
                                 DocumentState::kLocalMutations) ]);

  // The sum transform is not idempotent and the backend's updated value is ignored. The
  // ArrayUnion transform is recomputed and includes the backend value.
  [self
      applyRemoteEvent:FSTTestUpdateRemoteEvent(
                           FSTTestDoc("foo/bar", 1, @{@"sum" : @1337, @"array_union" : @[ @"bar" ]},
                                      DocumentState::kSynced),
                           {2}, {})];
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @1, @"array_union" : @[ @"bar", @"foo" ]},
                                 DocumentState::kLocalMutations) ]);
}

- (void)testHandlesMergeMutationWithTransformThenRemoteEvent {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutations:{
    FSTTestPatchMutation("foo/bar", @{}, {firebase::firestore::testutil::Field("sum")}),
        FSTTestTransformMutation(@"foo/bar",
                                 @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})
  }];

  FSTAssertContains(FSTTestDoc("foo/bar", 0, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 0, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"sum" : @1337}, DocumentState::kSynced),
                             {2})];

  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);
}

- (void)testHandlesPatchMutationWithTransformThenRemoteEvent {
  if ([self isTestBaseClass]) return;

  FSTQuery *query = FSTTestQuery("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutations:{
    FSTTestPatchMutation("foo/bar", @{}, {}),
        FSTTestTransformMutation(@"foo/bar",
                                 @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})
  }];

  FSTAssertNotContains(@"foo/bar");
  FSTAssertChanged(@[ FSTTestDeletedDoc("foo/bar", 0, NO) ]);

  // Note: This test reflects the current behavior, but it may be preferable to replay the
  // mutation once we receive the first value from the remote event.
  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             FSTTestDoc("foo/bar", 1, @{@"sum" : @1337}, DocumentState::kSynced),
                             {2})];

  FSTAssertContains(FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations));
  FSTAssertChanged(@[ FSTTestDoc("foo/bar", 1, @{@"sum" : @1}, DocumentState::kLocalMutations) ]);
}

@end

NS_ASSUME_NONNULL_END
