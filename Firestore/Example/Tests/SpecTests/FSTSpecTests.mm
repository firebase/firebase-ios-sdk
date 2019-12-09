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

#import "Firestore/Example/Tests/SpecTests/FSTSpecTests.h"

#import <FirebaseFirestore/FIRFirestoreErrors.h>

#include <map>
#include <memory>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Util/FSTClasses.h"

#import "Firestore/Example/Tests/SpecTests/FSTSyncEngineTestDriver.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/objc/objc_compatibility.h"
#include "Firestore/core/src/firebase/firestore/remote/existence_filter.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/types/optional.h"

namespace objc = firebase::firestore::objc;
namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::Error;
using firebase::firestore::auth::User;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::Query;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryData;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::nanopb::MakeByteString;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Status;
using firebase::firestore::util::TimerId;

using testutil::Doc;
using testutil::Filter;
using testutil::OrderBy;

NS_ASSUME_NONNULL_BEGIN

// Whether to run the benchmark spec tests.
// TODO(mrschmidt): Make this configurable via the tests schema.
static BOOL kRunBenchmarkTests = NO;

// Disables all other tests; useful for debugging. Multiple tests can have this tag and they'll all
// be run (but all others won't).
static NSString *const kExclusiveTag = @"exclusive";

// A tag for tests that should be excluded from execution (on iOS), useful to allow the platforms
// to temporarily diverge.
static NSString *const kNoIOSTag = @"no-ios";

// A tag for tests that exercise the multi-client behavior of the Web client. These tests are
// ignored on iOS.
static NSString *const kMultiClientTag = @"multi-client";

// A tag for tests that is assigned to the perf tests in "perf_spec.json". These tests are only run
// if `kRunBenchmarkTests` is set to 'YES'.
static NSString *const kBenchmarkTag = @"benchmark";

NSString *const kEagerGC = @"eager-gc";

NSString *const kDurablePersistence = @"durable-persistence";

namespace {

std::vector<TargetId> ConvertTargetsArray(NSArray<NSNumber *> *from) {
  std::vector<TargetId> result;
  for (NSNumber *targetID in from) {
    result.push_back(targetID.intValue);
  }
  return result;
}

ByteString MakeResumeToken(NSString *specString) {
  return MakeByteString([specString dataUsingEncoding:NSUTF8StringEncoding]);
}

}  // namespace

@interface FSTSpecTests ()
@property(nonatomic, strong) FSTSyncEngineTestDriver *driver;

@end

@implementation FSTSpecTests {
  BOOL _gcEnabled;
  BOOL _networkEnabled;
  FSTUserDataConverter *_converter;
}

- (std::unique_ptr<Persistence>)persistenceWithGCEnabled:(BOOL)GCEnabled {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (BOOL)shouldRunWithTags:(NSArray<NSString *> *)tags {
  if ([tags containsObject:kNoIOSTag]) {
    return NO;
  } else if ([tags containsObject:kMultiClientTag]) {
    return NO;
  } else if (!kRunBenchmarkTests && [tags containsObject:kBenchmarkTag]) {
    return NO;
  }
  return YES;
}

- (void)setUpForSpecWithConfig:(NSDictionary *)config {
  _converter = FSTTestUserDataConverter();

  // Store GCEnabled so we can re-use it in doRestart.
  NSNumber *GCEnabled = config[@"useGarbageCollection"];
  _gcEnabled = [GCEnabled boolValue];
  NSNumber *numClients = config[@"numClients"];
  if (numClients) {
    XCTAssertEqualObjects(numClients, @1, @"The iOS client does not support multi-client tests");
  }
  std::unique_ptr<Persistence> persistence = [self persistenceWithGCEnabled:_gcEnabled];
  self.driver = [[FSTSyncEngineTestDriver alloc] initWithPersistence:std::move(persistence)];
  [self.driver start];
}

- (void)tearDownForSpec {
  [self.driver shutdown];
}

/**
 * Xcode will run tests from any class that extends XCTestCase, but this doesn't work for
 * FSTSpecTests since it is incomplete without the implementations supplied by its subclasses.
 */
- (BOOL)isTestBaseClass {
  return [self class] == [FSTSpecTests class];
}

#pragma mark - Methods for constructing objects from specs.

- (Query)parseQuery:(id)querySpec {
  if ([querySpec isKindOfClass:[NSString class]]) {
    return testutil::Query(util::MakeString((NSString *)querySpec));
  } else if ([querySpec isKindOfClass:[NSDictionary class]]) {
    NSDictionary *queryDict = (NSDictionary *)querySpec;
    NSString *path = queryDict[@"path"];
    ResourcePath resource_path = ResourcePath::FromString(util::MakeString(path));
    std::shared_ptr<const std::string> collectionGroup =
        util::MakeStringPtr(queryDict[@"collectionGroup"]);
    Query query(std::move(resource_path), std::move(collectionGroup));
    if (queryDict[@"limit"]) {
      NSNumber *limitNumber = queryDict[@"limit"];
      auto limit = static_cast<int32_t>(limitNumber.integerValue);
      query = query.WithLimit(limit);
    }
    if (queryDict[@"filters"]) {
      NSArray<NSArray<id> *> *filters = queryDict[@"filters"];
      for (NSArray<id> *filter in filters) {
        std::string key = util::MakeString(filter[0]);
        std::string op = util::MakeString(filter[1]);
        FieldValue value = [_converter parsedQueryValue:filter[2]];
        query = query.AddingFilter(Filter(key, op, value));
      }
    }
    if (queryDict[@"orderBys"]) {
      NSArray *orderBys = queryDict[@"orderBys"];
      for (NSArray<NSString *> *orderBy in orderBys) {
        std::string field_path = util::MakeString(orderBy[0]);
        std::string direction = util::MakeString(orderBy[1]);
        query = query.AddingOrderBy(OrderBy(field_path, direction));
      }
    }
    return query;
  } else {
    XCTFail(@"Invalid query: %@", querySpec);
    return Query();
  }
}

- (SnapshotVersion)parseVersion:(NSNumber *_Nullable)version {
  return testutil::Version(version.longLongValue);
}

- (DocumentViewChange)parseChange:(NSDictionary *)jsonDoc ofType:(DocumentViewChange::Type)type {
  NSNumber *version = jsonDoc[@"version"];
  NSDictionary *options = jsonDoc[@"options"];
  DocumentState documentState = [options[@"hasLocalMutations"] isEqualToNumber:@YES]
                                    ? DocumentState::kLocalMutations
                                    : ([options[@"hasCommittedMutations"] isEqualToNumber:@YES]
                                           ? DocumentState::kCommittedMutations
                                           : DocumentState::kSynced);

  XCTAssert([jsonDoc[@"key"] isKindOfClass:[NSString class]]);
  FieldValue data = [_converter parsedQueryValue:jsonDoc[@"value"]];
  Document doc = Doc(util::MakeString((NSString *)jsonDoc[@"key"]), version.longLongValue, data,
                     documentState);
  return DocumentViewChange{doc, type};
}

#pragma mark - Methods for doing the steps of the spec test.

- (void)doListen:(NSArray *)listenSpec {
  Query query = [self parseQuery:listenSpec[1]];
  TargetId actualID = [self.driver addUserListenerWithQuery:std::move(query)];

  TargetId expectedID = [listenSpec[0] intValue];
  XCTAssertEqual(actualID, expectedID, @"targetID assigned to listen");
}

- (void)doUnlisten:(NSArray *)unlistenSpec {
  Query query = [self parseQuery:unlistenSpec[1]];
  [self.driver removeUserListenerWithQuery:std::move(query)];
}

- (void)doSet:(NSArray *)setSpec {
  [self.driver writeUserMutation:FSTTestSetMutation(setSpec[0], setSpec[1])];
}

- (void)doPatch:(NSArray *)patchSpec {
  [self.driver
      writeUserMutation:FSTTestPatchMutation(util::MakeString(patchSpec[0]), patchSpec[1], {})];
}

- (void)doDelete:(NSString *)key {
  [self.driver writeUserMutation:FSTTestDeleteMutation(key)];
}

- (void)doAddSnapshotsInSyncListener {
  [self.driver addSnapshotsInSyncListener];
}

- (void)doRemoveSnapshotsInSyncListener {
  [self.driver removeSnapshotsInSyncListener];
}

- (void)doWatchAck:(NSArray<NSNumber *> *)ackedTargets {
  WatchTargetChange change{WatchTargetChangeState::Added, ConvertTargetsArray(ackedTargets)};
  [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
}

- (void)doWatchCurrent:(NSArray<id> *)currentSpec {
  NSArray<NSNumber *> *currentTargets = currentSpec[0];
  ByteString resumeToken = MakeResumeToken(currentSpec[1]);
  WatchTargetChange change{WatchTargetChangeState::Current, ConvertTargetsArray(currentTargets),
                           resumeToken};
  [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
}

- (void)doWatchRemove:(NSDictionary *)watchRemoveSpec {
  Status error;
  NSDictionary *cause = watchRemoveSpec[@"cause"];
  if (cause) {
    int code = ((NSNumber *)cause[@"code"]).intValue;
    NSDictionary *userInfo = @{
      NSLocalizedDescriptionKey : @"Error from watchRemove.",
    };
    error = Status{static_cast<Error>(code), MakeString([userInfo description])};
  }
  WatchTargetChange change{WatchTargetChangeState::Removed,
                           ConvertTargetsArray(watchRemoveSpec[@"targetIds"]), error};
  [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
  // Unlike web, the FSTMockDatastore detects a watch removal with cause and will remove active
  // targets
}

- (void)doWatchEntity:(NSDictionary *)watchEntity {
  if (watchEntity[@"docs"]) {
    HARD_ASSERT(!watchEntity[@"doc"], "Exactly one of |doc| or |docs| needs to be set.");
    NSArray *docs = watchEntity[@"docs"];
    for (NSDictionary *doc in docs) {
      NSMutableDictionary *watchSpec = [NSMutableDictionary dictionary];
      watchSpec[@"doc"] = doc;
      if (watchEntity[@"targets"]) {
        watchSpec[@"targets"] = watchEntity[@"targets"];
      }
      if (watchEntity[@"removedTargets"]) {
        watchSpec[@"removedTargets"] = watchEntity[@"removedTargets"];
      }
      [self doWatchEntity:watchSpec];
    }
  } else if (watchEntity[@"doc"]) {
    NSDictionary *docSpec = watchEntity[@"doc"];
    DocumentKey key = FSTTestDocKey(docSpec[@"key"]);
    absl::optional<ObjectValue> value = [docSpec[@"value"] isKindOfClass:[NSNull class]]
                                            ? absl::optional<ObjectValue>{}
                                            : FSTTestObjectValue(docSpec[@"value"]);
    SnapshotVersion version = [self parseVersion:docSpec[@"version"]];
    MaybeDocument doc;
    if (value) {
      doc = Document(*std::move(value), key, version, DocumentState::kSynced);
    } else {
      doc = NoDocument(key, version, /* has_committed_mutations= */ false);
    }
    DocumentWatchChange change{ConvertTargetsArray(watchEntity[@"targets"]),
                               ConvertTargetsArray(watchEntity[@"removedTargets"]), std::move(key),
                               std::move(doc)};
    [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
  } else if (watchEntity[@"key"]) {
    DocumentKey docKey = FSTTestDocKey(watchEntity[@"key"]);
    DocumentWatchChange change{
        {}, ConvertTargetsArray(watchEntity[@"removedTargets"]), docKey, absl::nullopt};
    [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
  } else {
    HARD_FAIL("Either key, doc or docs must be set.");
  }
}

- (void)doWatchFilter:(NSArray *)watchFilter {
  NSArray<NSNumber *> *targets = watchFilter[0];
  HARD_ASSERT(targets.count == 1, "ExistenceFilters currently support exactly one target only.");

  int keyCount = watchFilter.count == 0 ? 0 : (int)watchFilter.count - 1;

  ExistenceFilter filter{keyCount};
  ExistenceFilterWatchChange change{filter, targets[0].intValue};
  [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
}

- (void)doWatchReset:(NSArray<NSNumber *> *)watchReset {
  WatchTargetChange change{WatchTargetChangeState::Reset, ConvertTargetsArray(watchReset)};
  [self.driver receiveWatchChange:change snapshotVersion:SnapshotVersion::None()];
}

- (void)doWatchSnapshot:(NSDictionary *)watchSnapshot {
  // The client will only respond to watchSnapshots if they are on a target change with an empty
  // set of target IDs.
  NSArray<NSNumber *> *targetIDs =
      watchSnapshot[@"targetIds"] ? watchSnapshot[@"targetIds"] : [NSArray array];
  ByteString resumeToken = MakeResumeToken(watchSnapshot[@"resumeToken"]);
  WatchTargetChange change{WatchTargetChangeState::NoChange, ConvertTargetsArray(targetIDs),
                           resumeToken};
  [self.driver receiveWatchChange:change
                  snapshotVersion:[self parseVersion:watchSnapshot[@"version"]]];
}

- (void)doWatchStreamClose:(NSDictionary *)closeSpec {
  NSDictionary *errorSpec = closeSpec[@"error"];
  int code = ((NSNumber *)(errorSpec[@"code"])).intValue;

  NSNumber *runBackoffTimer = closeSpec[@"runBackoffTimer"];
  // TODO(b/72313632): Incorporate backoff in iOS Spec Tests.
  HARD_ASSERT(runBackoffTimer.boolValue, "iOS Spec Tests don't support backoff.");

  [self.driver receiveWatchStreamError:code userInfo:errorSpec];
}

- (void)doWriteAck:(NSDictionary *)spec {
  SnapshotVersion version = [self parseVersion:spec[@"version"]];
  NSNumber *keepInQueue = spec[@"keepInQueue"];
  XCTAssertTrue(keepInQueue == nil || keepInQueue.boolValue == NO,
                @"'keepInQueue=true' is not supported on iOS and should only be set in "
                @"multi-client tests");

  MutationResult mutationResult(version, absl::nullopt);
  [self.driver receiveWriteAckWithVersion:version mutationResults:{mutationResult}];
}

- (void)doFailWrite:(NSDictionary *)spec {
  NSDictionary *errorSpec = spec[@"error"];
  NSNumber *keepInQueue = spec[@"keepInQueue"];

  int code = ((NSNumber *)(errorSpec[@"code"])).intValue;
  [self.driver receiveWriteError:code userInfo:errorSpec keepInQueue:keepInQueue.boolValue];
}

- (void)doDrainQueue {
  [self.driver drainQueue];
}

- (void)doRunTimer:(NSString *)timer {
  TimerId timerID;
  if ([timer isEqualToString:@"all"]) {
    timerID = TimerId::All;
  } else if ([timer isEqualToString:@"listen_stream_idle"]) {
    timerID = TimerId::ListenStreamIdle;
  } else if ([timer isEqualToString:@"listen_stream_connection_backoff"]) {
    timerID = TimerId::ListenStreamConnectionBackoff;
  } else if ([timer isEqualToString:@"write_stream_idle"]) {
    timerID = TimerId::WriteStreamIdle;
  } else if ([timer isEqualToString:@"write_stream_connection_backoff"]) {
    timerID = TimerId::WriteStreamConnectionBackoff;
  } else if ([timer isEqualToString:@"online_state_timeout"]) {
    timerID = TimerId::OnlineStateTimeout;
  } else {
    HARD_FAIL("runTimer spec step specified unknown timer: %s", timer);
  }

  [self.driver runTimer:timerID];
}

- (void)doDisableNetwork {
  _networkEnabled = NO;
  [self.driver disableNetwork];
}

- (void)doEnableNetwork {
  _networkEnabled = YES;
  [self.driver enableNetwork];
}

- (void)doChangeUser:(nullable id)UID {
  if ([UID isEqual:[NSNull null]]) {
    UID = nil;
  }
  [self.driver changeUser:User::FromUid(UID)];
}

- (void)doRestart {
  // Any outstanding user writes should be automatically re-sent, so we want to preserve them
  // when re-creating the driver.
  FSTOutstandingWriteQueues outstandingWrites = self.driver.outstandingWrites;
  User currentUser = self.driver.currentUser;

  [self.driver shutdown];

  std::unique_ptr<Persistence> persistence = [self persistenceWithGCEnabled:_gcEnabled];
  self.driver = [[FSTSyncEngineTestDriver alloc] initWithPersistence:std::move(persistence)
                                                         initialUser:currentUser
                                                   outstandingWrites:outstandingWrites];
  [self.driver start];
}

- (void)doStep:(NSDictionary *)step {
  NSNumber *clientIndex = step[@"clientIndex"];
  XCTAssertNil(clientIndex, @"The iOS client does not support switching clients");

  if (step[@"userListen"]) {
    [self doListen:step[@"userListen"]];
  } else if (step[@"userUnlisten"]) {
    [self doUnlisten:step[@"userUnlisten"]];
  } else if (step[@"userSet"]) {
    [self doSet:step[@"userSet"]];
  } else if (step[@"userPatch"]) {
    [self doPatch:step[@"userPatch"]];
  } else if (step[@"userDelete"]) {
    [self doDelete:step[@"userDelete"]];
  } else if (step[@"addSnapshotsInSyncListener"]) {
    [self doAddSnapshotsInSyncListener];
  } else if (step[@"removeSnapshotsInSyncListener"]) {
    [self doRemoveSnapshotsInSyncListener];
  } else if (step[@"drainQueue"]) {
    [self doDrainQueue];
  } else if (step[@"watchAck"]) {
    [self doWatchAck:step[@"watchAck"]];
  } else if (step[@"watchCurrent"]) {
    [self doWatchCurrent:step[@"watchCurrent"]];
  } else if (step[@"watchRemove"]) {
    [self doWatchRemove:step[@"watchRemove"]];
  } else if (step[@"watchEntity"]) {
    [self doWatchEntity:step[@"watchEntity"]];
  } else if (step[@"watchFilter"]) {
    [self doWatchFilter:step[@"watchFilter"]];
  } else if (step[@"watchReset"]) {
    [self doWatchReset:step[@"watchReset"]];
  } else if (step[@"watchSnapshot"]) {
    [self doWatchSnapshot:step[@"watchSnapshot"]];
  } else if (step[@"watchStreamClose"]) {
    [self doWatchStreamClose:step[@"watchStreamClose"]];
  } else if (step[@"watchProto"]) {
    // watchProto isn't yet used, and it's unclear how to create arbitrary protos from JSON.
    HARD_FAIL("watchProto is not yet supported.");
  } else if (step[@"writeAck"]) {
    [self doWriteAck:step[@"writeAck"]];
  } else if (step[@"failWrite"]) {
    [self doFailWrite:step[@"failWrite"]];
  } else if (step[@"runTimer"]) {
    [self doRunTimer:step[@"runTimer"]];
  } else if (step[@"enableNetwork"]) {
    if ([step[@"enableNetwork"] boolValue]) {
      [self doEnableNetwork];
    } else {
      [self doDisableNetwork];
    }
  } else if (step[@"changeUser"]) {
    [self doChangeUser:step[@"changeUser"]];
  } else if (step[@"restart"]) {
    [self doRestart];
  } else if (step[@"applyClientState"]) {
    XCTFail(@"'applyClientState' is not supported on iOS and should only be used in multi-client "
            @"tests");
  } else {
    XCTFail(@"Unknown step: %@", step);
  }
}

- (void)validateEvent:(FSTQueryEvent *)actual matches:(NSDictionary *)expected {
  Query expectedQuery = [self parseQuery:expected[@"query"]];
  XCTAssertEqual(actual.query, expectedQuery);
  if ([expected[@"errorCode"] integerValue] != 0) {
    XCTAssertNotNil(actual.error);
    XCTAssertEqual(actual.error.code, [expected[@"errorCode"] integerValue]);
  } else {
    std::vector<DocumentViewChange> expectedChanges;
    NSMutableArray *removed = expected[@"removed"];
    for (NSDictionary *changeSpec in removed) {
      expectedChanges.push_back([self parseChange:changeSpec
                                           ofType:DocumentViewChange::Type::Removed]);
    }
    NSMutableArray *added = expected[@"added"];
    for (NSDictionary *changeSpec in added) {
      expectedChanges.push_back([self parseChange:changeSpec
                                           ofType:DocumentViewChange::Type::Added]);
    }
    NSMutableArray *modified = expected[@"modified"];
    for (NSDictionary *changeSpec in modified) {
      expectedChanges.push_back([self parseChange:changeSpec
                                           ofType:DocumentViewChange::Type::Modified]);
    }
    NSMutableArray *metadata = expected[@"metadata"];
    for (NSDictionary *changeSpec in metadata) {
      expectedChanges.push_back([self parseChange:changeSpec
                                           ofType:DocumentViewChange::Type::Metadata]);
    }

    XCTAssertEqual(actual.viewSnapshot.value().document_changes().size(), expectedChanges.size());
    for (size_t i = 0; i != expectedChanges.size(); ++i) {
      XCTAssertTrue((actual.viewSnapshot.value().document_changes()[i] == expectedChanges[i]));
    }

    BOOL expectedHasPendingWrites =
        expected[@"hasPendingWrites"] ? [expected[@"hasPendingWrites"] boolValue] : NO;
    BOOL expectedIsFromCache = expected[@"fromCache"] ? [expected[@"fromCache"] boolValue] : NO;
    XCTAssertEqual(actual.viewSnapshot.value().has_pending_writes(), expectedHasPendingWrites,
                   @"hasPendingWrites");
    XCTAssertEqual(actual.viewSnapshot.value().from_cache(), expectedIsFromCache, @"isFromCache");
  }
}

- (void)validateExpectedSnapshotEvents:(NSArray *_Nullable)expectedEvents {
  NSArray<FSTQueryEvent *> *events = self.driver.capturedEventsSinceLastCall;

  if (!expectedEvents) {
    XCTAssertEqual(events.count, 0);
    for (FSTQueryEvent *event in events) {
      XCTFail(@"Unexpected event: %@", event);
    }
    return;
  }

  XCTAssertEqual(events.count, expectedEvents.count);
  events =
      [events sortedArrayUsingComparator:^NSComparisonResult(FSTQueryEvent *q1, FSTQueryEvent *q2) {
        return util::WrapCompare(q1.query.CanonicalId(), q2.query.CanonicalId());
      }];
  expectedEvents = [expectedEvents
      sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        Query leftQuery = [self parseQuery:left[@"query"]];
        Query rightQuery = [self parseQuery:right[@"query"]];
        return util::WrapCompare(leftQuery.CanonicalId(), rightQuery.CanonicalId());
      }];

  NSUInteger i = 0;
  for (; i < expectedEvents.count && i < events.count; ++i) {
    [self validateEvent:events[i] matches:expectedEvents[i]];
  }
  for (; i < expectedEvents.count; ++i) {
    XCTFail(@"Missing event: %@", expectedEvents[i]);
  }
  for (; i < events.count; ++i) {
    XCTFail(@"Unexpected event: %@", events[i]);
  }
}

- (void)validateExpectedState:(nullable NSDictionary *)expectedState {
  if (expectedState) {
    if (expectedState[@"numOutstandingWrites"]) {
      XCTAssertEqual([self.driver sentWritesCount],
                     [expectedState[@"numOutstandingWrites"] intValue]);
    }
    if (expectedState[@"writeStreamRequestCount"]) {
      XCTAssertEqual([self.driver writeStreamRequestCount],
                     [expectedState[@"writeStreamRequestCount"] intValue]);
    }
    if (expectedState[@"watchStreamRequestCount"]) {
      XCTAssertEqual([self.driver watchStreamRequestCount],
                     [expectedState[@"watchStreamRequestCount"] intValue]);
    }
    if (expectedState[@"limboDocs"]) {
      DocumentKeySet expectedLimboDocuments;
      NSArray *docNames = expectedState[@"limboDocs"];
      for (NSString *name in docNames) {
        expectedLimboDocuments = expectedLimboDocuments.insert(FSTTestDocKey(name));
      }
      // Update the expected limbo documents
      [self.driver setExpectedLimboDocuments:std::move(expectedLimboDocuments)];
    }
    if (expectedState[@"activeTargets"]) {
      __block std::unordered_map<TargetId, QueryData> expectedActiveTargets;
      [expectedState[@"activeTargets"]
          enumerateKeysAndObjectsUsingBlock:^(NSString *targetIDString, NSDictionary *queryData,
                                              BOOL *stop) {
            TargetId targetID = [targetIDString intValue];
            Query query = [self parseQuery:queryData[@"query"]];
            ByteString resumeToken = MakeResumeToken(queryData[@"resumeToken"]);
            // TODO(mcg): populate the purpose of the target once it's possible to encode that in
            // the spec tests. For now, hard-code that it's a listen despite the fact that it's not
            // always the right value.
            expectedActiveTargets[targetID] =
                QueryData(query.ToTarget(), targetID, 0, QueryPurpose::Listen,
                          SnapshotVersion::None(), std::move(resumeToken));
          }];
      [self.driver setExpectedActiveTargets:expectedActiveTargets];
    }
  }

  // Always validate the we received the expected number of callbacks.
  [self validateUserCallbacks:expectedState];
  // Always validate that the expected limbo docs match the actual limbo docs.
  [self validateLimboDocuments];
  // Always validate that the expected active targets match the actual active targets.
  [self validateActiveTargets];
}

- (void)validateSnapshotsInSyncEvents:(int)expectedSnapshotInSyncEvents {
  XCTAssertEqual(expectedSnapshotInSyncEvents, [self.driver snapshotsInSyncEvents]);
  [self.driver resetSnapshotsInSyncEvents];
}

- (void)validateUserCallbacks:(nullable NSDictionary *)expected {
  NSDictionary *expectedCallbacks = expected[@"userCallbacks"];
  NSArray<NSString *> *actualAcknowledgedDocs =
      [self.driver capturedAcknowledgedWritesSinceLastCall];
  NSArray<NSString *> *actualRejectedDocs = [self.driver capturedRejectedWritesSinceLastCall];

  if (expectedCallbacks) {
    XCTAssertTrue([actualAcknowledgedDocs isEqualToArray:expectedCallbacks[@"acknowledgedDocs"]]);
    XCTAssertTrue([actualRejectedDocs isEqualToArray:expectedCallbacks[@"rejectedDocs"]]);
  } else {
    XCTAssertEqual([actualAcknowledgedDocs count], 0);
    XCTAssertEqual([actualRejectedDocs count], 0);
  }
}

- (void)validateLimboDocuments {
  // Make a copy so it can modified while checking against the expected limbo docs.
  std::map<DocumentKey, TargetId> actualLimboDocs = self.driver.currentLimboDocuments;

  // Validate that each limbo doc has an expected active target
  for (const auto &kv : actualLimboDocs) {
    const auto &expected = [self.driver expectedActiveTargets];
    XCTAssertTrue(expected.find(kv.second) != expected.end(),
                  @"Found limbo doc without an expected active target");
  }

  for (const DocumentKey &expectedLimboDoc : self.driver.expectedLimboDocuments) {
    XCTAssert(actualLimboDocs.find(expectedLimboDoc) != actualLimboDocs.end(),
              @"Expected doc to be in limbo, but was not: %s", expectedLimboDoc.ToString().c_str());
    actualLimboDocs.erase(expectedLimboDoc);
  }
  XCTAssertTrue(actualLimboDocs.empty(), "%lu Unexpected docs in limbo, the first one is <%s, %d>",
                actualLimboDocs.size(), actualLimboDocs.begin()->first.ToString().c_str(),
                actualLimboDocs.begin()->second);
}

- (void)validateActiveTargets {
  if (!_networkEnabled) {
    return;
  }

  // Create a copy so we can modify it below
  std::unordered_map<TargetId, QueryData> actualTargets = [self.driver activeTargets];

  for (const auto &kv : [self.driver activeTargets]) {
    TargetId targetID = kv.first;
    const QueryData &queryData = kv.second;

    auto found = actualTargets.find(targetID);
    XCTAssertNotEqual(found, actualTargets.end(), @"Expected active target not found: %s",
                      queryData.ToString().c_str());

    // TODO(mcg): validate the purpose of the target once it's possible to encode that in the
    // spec tests. For now, only validate properties that can be validated.
    // XCTAssertEqualObjects(actualTargets[targetID], queryData);

    const QueryData &actual = found->second;
    XCTAssertEqual(actual.target(), queryData.target());
    XCTAssertEqual(actual.target_id(), queryData.target_id());
    XCTAssertEqual(actual.snapshot_version(), queryData.snapshot_version());
    XCTAssertEqual(actual.resume_token(), queryData.resume_token());

    actualTargets.erase(targetID);
  }

  XCTAssertTrue(actualTargets.empty(), "Unexpected active targets: %@",
                objc::Description(actualTargets));
}

- (void)runSpecTestSteps:(NSArray *)steps config:(NSDictionary *)config {
  @try {
    [self setUpForSpecWithConfig:config];
    for (NSDictionary *step in steps) {
      LOG_DEBUG("Doing step %s", step);
      [self doStep:step];
      [self validateExpectedSnapshotEvents:step[@"expectedSnapshotEvents"]];
      [self validateExpectedState:step[@"expectedState"]];
      int expectedSnapshotsInSyncEvents = [step[@"expectedSnapshotsInSyncEvents"] intValue];
      [self validateSnapshotsInSyncEvents:expectedSnapshotsInSyncEvents];
    }
    [self.driver validateUsage];
  } @finally {
    // Ensure that the driver is torn down even if the test is failing due to a thrown exception so
    // that any resources held by the driver are released. This is important when the driver is
    // backed by LevelDB because LevelDB locks its database. If -tearDownForSpec were not called
    // after an exception then subsequent attempts to open the LevelDB will fail, making it harder
    // to zero in on the spec tests as a culprit.
    [self tearDownForSpec];
  }
}

#pragma mark - The actual test methods.

- (void)testSpecTests {
  if ([self isTestBaseClass]) return;

  // Enumerate the .json files containing the spec tests.
  NSMutableArray<NSString *> *specFiles = [NSMutableArray array];
  NSMutableArray<NSDictionary *> *parsedSpecs = [NSMutableArray array];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSFileManager *fs = [NSFileManager defaultManager];
  BOOL exclusiveMode = NO;
  for (NSString *file in [fs enumeratorAtPath:[bundle resourcePath]]) {
    if (![@"json" isEqual:[file pathExtension]]) {
      continue;
    }

    // Read and parse the JSON from the file.
    NSString *fileName = [file stringByDeletingPathExtension];
    NSString *path = [bundle pathForResource:fileName ofType:@"json"];
    NSData *json = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(json);
    NSError *error = nil;
    id _Nullable parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];
    XCTAssertNil(error, @"%@", error);
    XCTAssertTrue([parsed isKindOfClass:[NSDictionary class]]);
    NSDictionary *testDict = (NSDictionary *)parsed;

    exclusiveMode = exclusiveMode || [self anyTestsAreMarkedExclusive:testDict];
    [specFiles addObject:fileName];
    [parsedSpecs addObject:testDict];
  }

  // Now iterate over them and run them.
  __block bool ranAtLeastOneTest = NO;
  for (NSUInteger i = 0; i < specFiles.count; i++) {
    NSLog(@"Spec test file: %@", specFiles[i]);
    // Iterate over the tests in the file and run them.
    [parsedSpecs[i] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      XCTAssertTrue([obj isKindOfClass:[NSDictionary class]]);
      NSDictionary *testDescription = (NSDictionary *)obj;
      NSString *describeName = testDescription[@"describeName"];
      NSString *itName = testDescription[@"itName"];
      NSString *name = [NSString stringWithFormat:@"%@ %@", describeName, itName];
      NSDictionary *config = testDescription[@"config"];
      NSArray *steps = testDescription[@"steps"];
      NSArray<NSString *> *tags = testDescription[@"tags"];

      BOOL runTest = !exclusiveMode || [tags indexOfObject:kExclusiveTag] != NSNotFound;
      if (runTest) {
        runTest = [self shouldRunWithTags:tags];
      }
      if (runTest) {
        NSLog(@"  Spec test: %@", name);
        [self runSpecTestSteps:steps config:config];
        ranAtLeastOneTest = YES;
      } else {
        NSLog(@"  [SKIPPED] Spec test: %@", name);
        NSString *comment = testDescription[@"comment"];
        if (comment) {
          NSLog(@"    %@", comment);
        }
      }
    }];
  }
  XCTAssertTrue(ranAtLeastOneTest);
}

- (BOOL)anyTestsAreMarkedExclusive:(NSDictionary *)tests {
  __block BOOL found = NO;
  [tests enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    XCTAssertTrue([obj isKindOfClass:[NSDictionary class]]);
    NSDictionary *testDescription = (NSDictionary *)obj;
    NSArray<NSString *> *tags = testDescription[@"tags"];
    if ([tags indexOfObject:kExclusiveTag] != NSNotFound) {
      found = YES;
      *stop = YES;
    }
  }];
  return found;
}

@end

NS_ASSUME_NONNULL_END
