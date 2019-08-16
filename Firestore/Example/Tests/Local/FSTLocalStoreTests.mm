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

#include <string>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Util/FSTClasses.h"

#import "Firestore/Example/Tests/Local/FSTLocalStoreTests.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/local_view_changes.h"
#include "Firestore/core/src/firebase/firestore/local/local_write_result.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/mutation_batch_result.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::Timestamp;
using firebase::firestore::auth::User;
using firebase::firestore::local::LocalViewChanges;
using firebase::firestore::local::LocalWriteResult;
using firebase::firestore::local::QueryData;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationBatch;
using firebase::firestore::model::MutationBatchResult;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::remote::RemoteEvent;
using firebase::firestore::remote::TestTargetMetadataProvider;
using firebase::firestore::remote::WatchChangeAggregator;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::util::Status;

using testutil::Array;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Key;
using testutil::Map;
using testutil::Query;
using testutil::UnknownDoc;
using testutil::Vector;

namespace {

std::vector<MaybeDocument> DocMapToArray(const MaybeDocumentMap &docs) {
  std::vector<MaybeDocument> result;
  for (const auto &kv : docs) {
    result.push_back(kv.second);
  }
  return result;
}

std::vector<Document> DocMapToArray(const DocumentMap &docs) {
  std::vector<Document> result;
  for (const auto &kv : docs.underlying_map()) {
    result.push_back(Document(kv.second));
  }
  return result;
}

}  // namespace

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalStoreTests ()

@property(nonatomic, strong, readwrite) id<FSTPersistence> localStorePersistence;
@property(nonatomic, strong, readwrite) FSTLocalStore *localStore;

@property(nonatomic, assign, readwrite) TargetId lastTargetID;

@end

@implementation FSTLocalStoreTests {
  std::vector<MutationBatch> _batches;
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

- (void)writeMutation:(Mutation)mutation {
  [self writeMutations:{std::move(mutation)}];
}

- (void)writeMutations:(std::vector<Mutation> &&)mutations {
  auto mutationsCopy = mutations;
  LocalWriteResult result = [self.localStore locallyWriteMutations:std::move(mutationsCopy)];
  _batches.emplace_back(result.batch_id(), Timestamp::Now(), std::vector<Mutation>{},
                        std::move(mutations));
  _lastChanges = result.changes();
}

- (void)applyRemoteEvent:(const RemoteEvent &)event {
  _lastChanges = [self.localStore applyRemoteEvent:event];
}

- (void)notifyLocalViewChanges:(LocalViewChanges)changes {
  [self.localStore notifyLocalViewChanges:std::vector<LocalViewChanges>{std::move(changes)}];
}

- (void)acknowledgeMutationWithVersion:(FSTTestSnapshotVersion)documentVersion
                       transformResult:(id _Nullable)transformResult {
  XCTAssertGreaterThan(_batches.size(), 0, @"Missing batch to acknowledge.");
  MutationBatch batch = _batches.front();
  _batches.erase(_batches.begin());

  XCTAssertEqual(batch.mutations().size(), 1,
                 @"Acknowledging more than one mutation not supported.");
  SnapshotVersion version = testutil::Version(documentVersion);

  absl::optional<std::vector<FieldValue>> mutationTransformResult;
  if (transformResult) {
    mutationTransformResult = std::vector<FieldValue>{FSTTestFieldValue(transformResult)};
  }

  MutationResult mutationResult(version, mutationTransformResult);
  MutationBatchResult result(batch, version, {mutationResult}, {});
  _lastChanges = [self.localStore acknowledgeBatchWithResult:result];
}

- (void)acknowledgeMutationWithVersion:(FSTTestSnapshotVersion)documentVersion {
  [self acknowledgeMutationWithVersion:documentVersion transformResult:nil];
}

- (void)rejectMutation {
  MutationBatch batch = _batches.front();
  _batches.erase(_batches.begin());
  _lastChanges = [self.localStore rejectBatchID:batch.batch_id()];
}

- (TargetId)allocateQuery:(core::Query)query {
  QueryData queryData = [self.localStore allocateQuery:std::move(query)];
  self.lastTargetID = queryData.target_id();
  return queryData.target_id();
}

/** Asserts that the last target ID is the given number. */
#define FSTAssertTargetID(targetID)              \
  do {                                           \
    XCTAssertEqual(self.lastTargetID, targetID); \
  } while (0)

/** Asserts that a the lastChanges contain the docs in the given array. */
#define FSTAssertChanged(...)                             \
  do {                                                    \
    std::vector<MaybeDocument> expected = {__VA_ARGS__};  \
    XCTAssertEqual(_lastChanges.size(), expected.size()); \
    auto lastChangesList = DocMapToArray(_lastChanges);   \
    XCTAssertEqual(lastChangesList, expected);            \
    _lastChanges = MaybeDocumentMap{};                    \
  } while (0)

/** Asserts that the given keys were removed. */
#define FSTAssertRemoved(...)                             \
  do {                                                    \
    std::vector<std::string> keyPaths = {__VA_ARGS__};    \
    XCTAssertEqual(_lastChanges.size(), keyPaths.size()); \
    auto keyPathIterator = keyPaths.begin();              \
    for (const auto &kv : _lastChanges) {                 \
      const DocumentKey &actualKey = kv.first;            \
      const MaybeDocument &value = kv.second;             \
      DocumentKey expectedKey = Key(*keyPathIterator);    \
      XCTAssertEqual(actualKey, expectedKey);             \
      XCTAssertTrue(value.is_no_document());              \
      ++keyPathIterator;                                  \
    }                                                     \
    _lastChanges = MaybeDocumentMap{};                    \
  } while (0)

/** Asserts that the given local store contains the given document. */
#define FSTAssertContains(document)                                                       \
  do {                                                                                    \
    MaybeDocument expected = (document);                                                  \
    absl::optional<MaybeDocument> actual = [self.localStore readDocument:expected.key()]; \
    XCTAssertEqual(actual, expected);                                                     \
  } while (0)

/** Asserts that the given local store does not contain the given document. */
#define FSTAssertNotContains(keyPathString)                                    \
  do {                                                                         \
    DocumentKey key = Key(keyPathString);                                      \
    absl::optional<MaybeDocument> actual = [self.localStore readDocument:key]; \
    XCTAssertEqual(actual, absl::nullopt);                                     \
  } while (0)

- (void)testMutationBatchKeys {
  if ([self isTestBaseClass]) return;

  Mutation base = FSTTestSetMutation(@"foo/ignore", @{@"foo" : @"bar"});
  Mutation set1 = FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"});
  Mutation set2 = FSTTestSetMutation(@"bar/baz", @{@"bar" : @"baz"});
  MutationBatch batch = MutationBatch(1, Timestamp::Now(), {base}, {set1, set2});
  DocumentKeySet keys = batch.keys();
  XCTAssertEqual(keys.size(), 2u);
}

- (void)testHandlesSetMutation {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:0];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kCommittedMutations));
  if ([self gcIsEager]) {
    // Nothing is pinning this anymore, as it has been acknowledged and there are no targets active.
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kCommittedMutations));
  }
}

- (void)testHandlesSetMutationThenDocument {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));

  TargetId targetID = [self allocateQuery:Query("foo")];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 2, Map("it", "changed")),
                                                  {targetID}, {})];
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar"), DocumentState::kLocalMutations));
}

- (void)testHandlesAckThenRejectThenRemoteEvent {
  if ([self isTestBaseClass]) return;

  // Start a query that requires acks to be held.
  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));

  // The last seen version is zero, so this ack must be held.
  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(Doc("foo/bar", 1, Map("foo", "bar"), DocumentState::kCommittedMutations));

  // Under eager GC, there is no longer a reference for the document, and it should be
  // deleted.
  if ([self gcIsEager]) {
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar"), DocumentState::kCommittedMutations));
  }

  [self writeMutation:FSTTestSetMutation(@"bar/baz", @{@"bar" : @"baz"})];
  FSTAssertChanged(Doc("bar/baz", 0, Map("bar", "baz"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("bar/baz", 0, Map("bar", "baz"), DocumentState::kLocalMutations));

  [self rejectMutation];
  FSTAssertRemoved("bar/baz");
  FSTAssertNotContains("bar/baz");

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 2, Map("it", "changed")),
                                                 {targetID})];
  FSTAssertChanged(Doc("foo/bar", 2, Map("it", "changed")));
  FSTAssertContains(Doc("foo/bar", 2, Map("it", "changed")));
  FSTAssertNotContains("bar/baz");
}

- (void)testHandlesDeletedDocumentThenSetMutationThenAck {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(DeletedDoc("foo/bar", 2), {targetID}, {})];
  FSTAssertRemoved("foo/bar");
  // Under eager GC, there is no longer a reference for the document, and it should be
  // deleted.
  if (![self gcIsEager]) {
    FSTAssertContains(DeletedDoc("foo/bar", 2, NO));
  } else {
    FSTAssertNotContains("foo/bar");
  }

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  // Can now remove the target, since we have a mutation pinning the document
  [self.localStore releaseQuery:query];
  // Verify we didn't lose anything
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3];
  FSTAssertChanged(Doc("foo/bar", 3, Map("foo", "bar"), DocumentState::kCommittedMutations));
  // It has been acknowledged, and should no longer be retained as there is no target and mutation
  if ([self gcIsEager]) {
    FSTAssertNotContains("foo/bar");
  }
}

- (void)testHandlesSetMutationThenDeletedDocument {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(DeletedDoc("foo/bar", 2), {targetID}, {})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
}

- (void)testHandlesDocumentThenSetMutationThenAckThenDocument {
  if ([self isTestBaseClass]) return;

  // Start a query that requires acks to be held.
  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 2, Map("it", "base")), {targetID})];
  FSTAssertChanged(Doc("foo/bar", 2, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 2, Map("it", "base")));

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"})];
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar"), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3];
  // we haven't seen the remote event yet, so the write is still held.
  FSTAssertChanged(Doc("foo/bar", 3, Map("foo", "bar"), DocumentState::kCommittedMutations));
  FSTAssertContains(Doc("foo/bar", 3, Map("foo", "bar"), DocumentState::kCommittedMutations));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 3, Map("it", "changed")),
                                                  {targetID}, {})];
  FSTAssertChanged(Doc("foo/bar", 3, Map("it", "changed")));
  FSTAssertContains(Doc("foo/bar", 3, Map("it", "changed")));
}

- (void)testHandlesPatchWithoutPriorDocument {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved("foo/bar");
  FSTAssertNotContains("foo/bar");

  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(UnknownDoc("foo/bar", 1));
  if ([self gcIsEager]) {
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(UnknownDoc("foo/bar", 1));
  }
}

- (void)testHandlesPatchMutationThenDocumentThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved("foo/bar");
  FSTAssertNotContains("foo/bar");

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {targetID})];
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("foo", "bar", "it", "base"), DocumentState::kLocalMutations));
  FSTAssertContains(
      Doc("foo/bar", 1, Map("foo", "bar", "it", "base"), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:2];
  // We still haven't seen the remote events for the patch, so the local changes remain, and there
  // are no changes
  FSTAssertChanged(
      Doc("foo/bar", 2, Map("foo", "bar", "it", "base"), DocumentState::kCommittedMutations));
  FSTAssertContains(
      Doc("foo/bar", 2, Map("foo", "bar", "it", "base"), DocumentState::kCommittedMutations));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             Doc("foo/bar", 2, Map("foo", "bar", "it", "base")), {targetID}, {})];

  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar", "it", "base")));
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar", "it", "base")));
}

- (void)testHandlesPatchMutationThenAckThenDocument {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved("foo/bar");
  FSTAssertNotContains("foo/bar");

  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(UnknownDoc("foo/bar", 1));

  // There's no target pinning the doc, and we've ack'd the mutation.
  if ([self gcIsEager]) {
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(UnknownDoc("foo/bar", 1));
  }

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {targetID},
                                                  {})];
  FSTAssertChanged(Doc("foo/bar", 1, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 1, Map("it", "base")));
}

- (void)testHandlesDeleteMutationThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar"));

  [self acknowledgeMutationWithVersion:1];
  FSTAssertRemoved("foo/bar");
  // There's no target pinning the doc, and we've ack'd the mutation.
  if ([self gcIsEager]) {
    FSTAssertNotContains("foo/bar");
  }
}

- (void)testHandlesDocumentThenDeleteMutationThenAck {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {targetID},
                                                  {})];
  FSTAssertChanged(Doc("foo/bar", 1, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 1, Map("it", "base")));

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar"));

  // Remove the target so only the mutation is pinning the document
  [self.localStore releaseQuery:query];

  [self acknowledgeMutationWithVersion:2];
  FSTAssertRemoved("foo/bar");
  if ([self gcIsEager]) {
    // Neither the target nor the mutation pin the document, it should be gone.
    FSTAssertNotContains("foo/bar");
  }
}

- (void)testHandlesDeleteMutationThenDocumentThenAck {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar"));

  // Add the document to a target so it will remain in persistence even when ack'd
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {targetID},
                                                  {})];
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar"));

  // Don't need to keep it pinned anymore
  [self.localStore releaseQuery:query];

  [self acknowledgeMutationWithVersion:2];
  FSTAssertRemoved("foo/bar");
  if ([self gcIsEager]) {
    // The doc is not pinned in a target and we've acknowledged the mutation. It shouldn't exist
    // anymore.
    FSTAssertNotContains("foo/bar");
  }
}

- (void)testHandlesDocumentThenDeletedDocumentThenDocument {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {targetID},
                                                  {})];
  FSTAssertChanged(Doc("foo/bar", 1, Map("it", "base")));
  FSTAssertContains(Doc("foo/bar", 1, Map("it", "base")));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(DeletedDoc("foo/bar", 2), {targetID}, {})];
  FSTAssertRemoved("foo/bar");
  if (![self gcIsEager]) {
    FSTAssertContains(DeletedDoc("foo/bar", 2));
  }

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 3, Map("it", "changed")),
                                                  {targetID}, {})];
  FSTAssertChanged(Doc("foo/bar", 3, Map("it", "changed")));
  FSTAssertContains(Doc("foo/bar", 3, Map("it", "changed")));
}

- (void)testHandlesSetMutationThenPatchMutationThenDocumentThenAckThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "old"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "old"), DocumentState::kLocalMutations));

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 1, Map("it", "base")), {targetID},
                                                  {})];
  FSTAssertChanged(Doc("foo/bar", 1, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar"), DocumentState::kLocalMutations));

  [self.localStore releaseQuery:query];
  [self acknowledgeMutationWithVersion:2];  // delete mutation
  FSTAssertChanged(Doc("foo/bar", 2, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar"), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3];  // patch mutation
  FSTAssertChanged(Doc("foo/bar", 3, Map("foo", "bar"), DocumentState::kCommittedMutations));
  if ([self gcIsEager]) {
    // we've ack'd all of the mutations, nothing is keeping this pinned anymore
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(Doc("foo/bar", 3, Map("foo", "bar"), DocumentState::kCommittedMutations));
  }
}

- (void)testHandlesSetMutationAndPatchMutationTogether {
  if ([self isTestBaseClass]) return;

  [self writeMutations:{
    FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"}),
        FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})
  }];

  FSTAssertChanged(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
}

- (void)testHandlesSetMutationThenPatchMutationThenReject {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"})];
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "old"), DocumentState::kLocalMutations));
  [self acknowledgeMutationWithVersion:1];
  FSTAssertNotContains("foo/bar");

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  // A blind patch is not visible in the cache
  FSTAssertNotContains("foo/bar");

  [self rejectMutation];
  FSTAssertNotContains("foo/bar");
}

- (void)testHandlesSetMutationsAndPatchMutationOfJustOneTogether {
  if ([self isTestBaseClass]) return;

  [self writeMutations:{
    FSTTestSetMutation(@"foo/bar", @{@"foo" : @"old"}),
        FSTTestSetMutation(@"bar/baz", @{@"bar" : @"baz"}),
        FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})
  }];

  FSTAssertChanged(Doc("bar/baz", 0, Map("bar", "baz"), DocumentState::kLocalMutations),
                   Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("bar/baz", 0, Map("bar", "baz"), DocumentState::kLocalMutations));
}

- (void)testHandlesDeleteMutationThenPatchMutationThenAckThenAck {
  if ([self isTestBaseClass]) return;

  [self writeMutation:FSTTestDeleteMutation(@"foo/bar")];
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar"));

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar"));

  [self acknowledgeMutationWithVersion:2];  // delete mutation
  FSTAssertRemoved("foo/bar");
  FSTAssertContains(DeletedDoc("foo/bar", 2, /* has_committed_mutations= */ true));

  [self acknowledgeMutationWithVersion:3];  // patch mutation
  FSTAssertChanged(UnknownDoc("foo/bar", 3));
  if ([self gcIsEager]) {
    // There are no more pending mutations, the doc has been dropped
    FSTAssertNotContains("foo/bar");
  } else {
    FSTAssertContains(UnknownDoc("foo/bar", 3));
  }
}

- (void)testCollectsGarbageAfterChangeBatchWithNoTargetIDs {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  [self applyRemoteEvent:FSTTestUpdateRemoteEventWithLimboTargets(DeletedDoc("foo/bar", 2), {}, {},
                                                                  {1})];
  FSTAssertNotContains("foo/bar");

  [self applyRemoteEvent:FSTTestUpdateRemoteEventWithLimboTargets(
                             Doc("foo/bar", 2, Map("foo", "bar")), {}, {}, {1})];
  FSTAssertNotContains("foo/bar");
}

- (void)testCollectsGarbageAfterChangeBatch {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 2, Map("foo", "bar")), {targetID})];
  FSTAssertContains(Doc("foo/bar", 2, Map("foo", "bar")));

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 2, Map("foo", "baz")), {},
                                                  {targetID})];

  FSTAssertNotContains("foo/bar");
}

- (void)testCollectsGarbageAfterAcknowledgedMutation {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 0, Map("foo", "old")), {targetID},
                                                  {})];
  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  // Release the query so that our target count goes back to 0 and we are considered up-to-date.
  [self.localStore releaseQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bah", @{@"foo" : @"bah"})];
  [self writeMutation:FSTTestDeleteMutation(@"foo/baz")];
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bah", 0, Map("foo", "bah"), DocumentState::kLocalMutations));
  FSTAssertContains(DeletedDoc("foo/baz"));

  [self acknowledgeMutationWithVersion:3];
  FSTAssertNotContains("foo/bar");
  FSTAssertContains(Doc("foo/bah", 0, Map("foo", "bah"), DocumentState::kLocalMutations));
  FSTAssertContains(DeletedDoc("foo/baz"));

  [self acknowledgeMutationWithVersion:4];
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertContains(DeletedDoc("foo/baz"));

  [self acknowledgeMutationWithVersion:5];
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertNotContains("foo/baz");
}

- (void)testCollectsGarbageAfterRejectedMutation {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 0, Map("foo", "old")), {targetID},
                                                  {})];
  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"foo" : @"bar"}, {})];
  // Release the query so that our target count goes back to 0 and we are considered up-to-date.
  [self.localStore releaseQuery:query];

  [self writeMutation:FSTTestSetMutation(@"foo/bah", @{@"foo" : @"bah"})];
  [self writeMutation:FSTTestDeleteMutation(@"foo/baz")];
  FSTAssertContains(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations));
  FSTAssertContains(Doc("foo/bah", 0, Map("foo", "bah"), DocumentState::kLocalMutations));
  FSTAssertContains(DeletedDoc("foo/baz"));

  [self rejectMutation];  // patch mutation
  FSTAssertNotContains("foo/bar");
  FSTAssertContains(Doc("foo/bah", 0, Map("foo", "bah"), DocumentState::kLocalMutations));
  FSTAssertContains(DeletedDoc("foo/baz"));

  [self rejectMutation];  // set mutation
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertContains(DeletedDoc("foo/baz"));

  [self rejectMutation];  // delete mutation
  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/bah");
  FSTAssertNotContains("foo/baz");
}

- (void)testPinsDocumentsInTheLocalView {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  core::Query query = Query("foo");
  TargetId targetID = [self allocateQuery:query];

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 1, Map("foo", "bar")), {targetID})];
  [self writeMutation:FSTTestSetMutation(@"foo/baz", @{@"foo" : @"baz"})];
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar")));
  FSTAssertContains(Doc("foo/baz", 0, Map("foo", "baz"), DocumentState::kLocalMutations));

  [self notifyLocalViewChanges:TestViewChanges(targetID, @[ @"foo/bar", @"foo/baz" ], @[])];
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar")));
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 1, Map("foo", "bar")), {},
                                                  {targetID})];
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/baz", 2, Map("foo", "baz")), {targetID},
                                                  {})];
  FSTAssertContains(Doc("foo/baz", 2, Map("foo", "baz"), DocumentState::kLocalMutations));
  [self acknowledgeMutationWithVersion:2];
  FSTAssertContains(Doc("foo/baz", 2, Map("foo", "baz")));
  FSTAssertContains(Doc("foo/bar", 1, Map("foo", "bar")));
  FSTAssertContains(Doc("foo/baz", 2, Map("foo", "baz")));

  [self notifyLocalViewChanges:TestViewChanges(targetID, @[], @[ @"foo/bar", @"foo/baz" ])];
  [self.localStore releaseQuery:query];

  FSTAssertNotContains("foo/bar");
  FSTAssertNotContains("foo/baz");
}

- (void)testThrowsAwayDocumentsWithUnknownTargetIDsImmediately {
  if ([self isTestBaseClass]) return;
  if (![self gcIsEager]) return;

  TargetId targetID = 321;
  [self applyRemoteEvent:FSTTestUpdateRemoteEventWithLimboTargets(Doc("foo/bar", 1, Map()), {}, {},
                                                                  {targetID})];

  FSTAssertNotContains("foo/bar");
}

- (void)testCanExecuteDocumentQueries {
  if ([self isTestBaseClass]) return;

  [self.localStore locallyWriteMutations:{
    FSTTestSetMutation(@"foo/bar", @{@"foo" : @"bar"}),
        FSTTestSetMutation(@"foo/baz", @{@"foo" : @"baz"}),
        FSTTestSetMutation(@"foo/bar/Foo/Bar", @{@"Foo" : @"Bar"})
  }];
  core::Query query = Query("foo/bar");
  DocumentMap docs = [self.localStore executeQuery:query];
  XCTAssertEqual(DocMapToArray(docs),
                 Vector(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations)));
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
  core::Query query = Query("foo");
  DocumentMap docs = [self.localStore executeQuery:query];
  XCTAssertEqual(DocMapToArray(docs),
                 Vector(Doc("foo/bar", 0, Map("foo", "bar"), DocumentState::kLocalMutations),
                        Doc("foo/baz", 0, Map("foo", "baz"), DocumentState::kLocalMutations)));
}

- (void)testCanExecuteMixedCollectionQueries {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/baz", 10, Map("a", "b")), {2}, {})];
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 20, Map("a", "b")), {2}, {})];

  [self.localStore locallyWriteMutations:{ FSTTestSetMutation(@"foo/bonk", @{@"a" : @"b"}) }];

  DocumentMap docs = [self.localStore executeQuery:query];
  XCTAssertEqual(DocMapToArray(docs),
                 Vector(Doc("foo/bar", 20, Map("a", "b")), Doc("foo/baz", 10, Map("a", "b")),
                        Doc("foo/bonk", 0, Map("a", "b"), DocumentState::kLocalMutations)));
}

- (void)testPersistsResumeTokens {
  if ([self isTestBaseClass]) return;
  // This test only works in the absence of the FSTEagerGarbageCollector.
  if ([self gcIsEager]) return;

  core::Query query = Query("foo/bar");
  QueryData queryData = [self.localStore allocateQuery:query];
  ListenSequenceNumber initialSequenceNumber = queryData.sequence_number();
  TargetId targetID = queryData.target_id();
  ByteString resumeToken = testutil::ResumeToken(1000);

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
  QueryData queryData2 = [self.localStore allocateQuery:query];
  XCTAssertEqual(queryData2.resume_token(), resumeToken);

  // The sequence number should have been bumped when we saved the new resume token.
  ListenSequenceNumber newSequenceNumber = queryData2.sequence_number();
  XCTAssertGreaterThan(newSequenceNumber, initialSequenceNumber);
}

- (void)testRemoteDocumentKeysForTarget {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/baz", 10, Map("a", "b")), {2})];
  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 20, Map("a", "b")), {2})];

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
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 0), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0), DocumentState::kLocalMutations));

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})];
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 1), DocumentState::kLocalMutations));

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]})];
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 3), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 3), DocumentState::kLocalMutations));
}

- (void)testHandlesSetMutationThenAckThenTransformMutationThenAckThenTransformMutation {
  if ([self isTestBaseClass]) return;

  // Since this test doesn't start a listen, Eager GC removes the documents from the cache as
  // soon as the mutation is applied. This creates a lot of special casing in this unit test but
  // does not expand its test coverage.
  if ([self gcIsEager]) return;

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0})];
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 0), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:1];
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 0), DocumentState::kCommittedMutations));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0), DocumentState::kCommittedMutations));

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})];
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:2 transformResult:@1];
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 1), DocumentState::kCommittedMutations));
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 1), DocumentState::kCommittedMutations));

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]})];
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 3), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 3), DocumentState::kLocalMutations));
}

- (void)testHandlesSetMutationThenTransformMutationThenRemoteEventThenTransformMutation {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0})];
  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 0), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 0), DocumentState::kLocalMutations));

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 1, Map("sum", 0)), {2})];

  [self acknowledgeMutationWithVersion:1];
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 0)));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0)));

  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})];
  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));

  // The value in this remote event gets ignored since we still have a pending transform mutation.
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(Doc("foo/bar", 2, Map("sum", 0)), {2}, {})];
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 1), DocumentState::kLocalMutations));

  // Add another increment. Note that we still compute the increment based on the local value.
  [self writeMutation:FSTTestTransformMutation(
                          @"foo/bar", @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:2]})];
  FSTAssertContains(Doc("foo/bar", 2, Map("sum", 3), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 2, Map("sum", 3), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:3 transformResult:@1];
  FSTAssertContains(Doc("foo/bar", 3, Map("sum", 3), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 3, Map("sum", 3), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:4 transformResult:@1339];
  FSTAssertContains(Doc("foo/bar", 4, Map("sum", 1339), DocumentState::kCommittedMutations));
  FSTAssertChanged(Doc("foo/bar", 4, Map("sum", 1339), DocumentState::kCommittedMutations));
}

- (void)testHoldsBackOnlyNonIdempotentTransforms {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"sum" : @0, @"array_union" : @[]})];
  FSTAssertChanged(
      Doc("foo/bar", 0, Map("sum", 0, "array_union", Array()), DocumentState::kLocalMutations));

  [self acknowledgeMutationWithVersion:1];
  FSTAssertChanged(
      Doc("foo/bar", 1, Map("sum", 0, "array_union", Array()), DocumentState::kCommittedMutations));

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(
                             Doc("foo/bar", 1, Map("sum", 0, "array_union", Array())), {2})];
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 0, "array_union", Array())));

  [self writeMutations:{
    FSTTestTransformMutation(@"foo/bar",
                             @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}),
        FSTTestTransformMutation(
            @"foo/bar",
            @{@"array_union" : [FIRFieldValue fieldValueForArrayUnion:@[ @"foo" ]]})
  }];

  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1, "array_union", Array("foo")),
                       DocumentState::kLocalMutations));

  // The sum transform is not idempotent and the backend's updated value is ignored. The
  // ArrayUnion transform is recomputed and includes the backend value.
  [self applyRemoteEvent:FSTTestUpdateRemoteEvent(
                             Doc("foo/bar", 1, Map("sum", 1337, "array_union", Array("bar"))), {2},
                             {})];
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1, "array_union", Array("bar", "foo")),
                       DocumentState::kLocalMutations));
}

- (void)testHandlesMergeMutationWithTransformThenRemoteEvent {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutations:{
    FSTTestPatchMutation("foo/bar", @{}, {firebase::firestore::testutil::Field("sum")}),
        FSTTestTransformMutation(@"foo/bar",
                                 @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})
  }];

  FSTAssertContains(Doc("foo/bar", 0, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 0, Map("sum", 1), DocumentState::kLocalMutations));

  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 1, Map("sum", 1337)), {2})];

  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));
}

- (void)testHandlesPatchMutationWithTransformThenRemoteEvent {
  if ([self isTestBaseClass]) return;

  core::Query query = Query("foo");
  [self allocateQuery:query];
  FSTAssertTargetID(2);

  [self writeMutations:{
    FSTTestPatchMutation("foo/bar", @{}, {}),
        FSTTestTransformMutation(@"foo/bar",
                                 @{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]})
  }];

  FSTAssertNotContains("foo/bar");
  FSTAssertChanged(DeletedDoc("foo/bar"));

  // Note: This test reflects the current behavior, but it may be preferable to replay the
  // mutation once we receive the first value from the remote event.
  [self applyRemoteEvent:FSTTestAddedRemoteEvent(Doc("foo/bar", 1, Map("sum", 1337)), {2})];

  FSTAssertContains(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));
  FSTAssertChanged(Doc("foo/bar", 1, Map("sum", 1), DocumentState::kLocalMutations));
}

- (void)testGetHighestUnacknowledgeBatchId {
  if ([self isTestBaseClass]) return;

  XCTAssertEqual(-1, [self.localStore getHighestUnacknowledgedBatchId]);

  [self writeMutation:FSTTestSetMutation(@"foo/bar", @{@"abc" : @123})];
  XCTAssertEqual(1, [self.localStore getHighestUnacknowledgedBatchId]);

  [self writeMutation:FSTTestPatchMutation("foo/bar", @{@"abc" : @321}, {})];
  XCTAssertEqual(2, [self.localStore getHighestUnacknowledgedBatchId]);

  [self acknowledgeMutationWithVersion:1];
  XCTAssertEqual(2, [self.localStore getHighestUnacknowledgedBatchId]);

  [self rejectMutation];
  XCTAssertEqual(-1, [self.localStore getHighestUnacknowledgedBatchId]);
}

@end

NS_ASSUME_NONNULL_END
