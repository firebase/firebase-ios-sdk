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

#include <stddef.h>

#include <algorithm>
#include <limits>
#include <map>
#include <memory>
#include <set>
#include <sstream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FSTUserDataReader.h"

#import "Firestore/Example/Tests/SpecTests/FSTSyncEngineTestDriver.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/auth/user.h"
#include "Firestore/core/src/bundle/bundle_reader.h"
#include "Firestore/core/src/bundle/bundle_serializer.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/model/types.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/remote/existence_filter.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/remote/watch_change.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/byte_stream_cpp.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/filesystem.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/src/util/to_string.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/memory/memory.h"
#include "absl/types/optional.h"

namespace objc = firebase::firestore::objc;
namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::Error;
using firebase::firestore::api::LoadBundleTask;
using firebase::firestore::auth::User;
using firebase::firestore::bundle::BundleReader;
using firebase::firestore::bundle::BundleSerializer;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::Query;
using firebase::firestore::google_firestore_v1_ArrayValue;
using firebase::firestore::google_firestore_v1_Value;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryPurpose;
using firebase::firestore::local::TargetData;
using firebase::firestore::model::Document;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::MutableDocument;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::nanopb::MakeByteString;
using firebase::firestore::nanopb::Message;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::Path;
using firebase::firestore::util::Status;
using firebase::firestore::util::TimerId;

using testutil::Doc;
using testutil::Filter;
using testutil::OrderBy;

NS_ASSUME_NONNULL_BEGIN

// Whether to run the benchmark spec tests.
// TODO(mrschmidt): Make this configurable via the tests schema.
static BOOL kRunBenchmarkTests = NO;

// The name of an environment variable whose value is a filter that specifies which tests to
// execute. The value of this environment variable is a regular expression that is matched against
// the name of each test. Using this environment variable is an alternative to setting the
// kExclusiveTag tag, which requires modifying the JSON file. When this environment variable is set
// to a non-empty value, a test will be executed if and only if its name matches this regular
// expression. In this context, a test's "name" is the result of appending its "itName" to its
// "describeName", separated by a space character.
static NSString *const kTestFilterEnvKey = @"SPEC_TEST_FILTER";

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

NSString *ToDocumentListString(const std::set<DocumentKey> &keys) {
  std::vector<std::string> strings;
  strings.reserve(keys.size());
  for (const auto &key : keys) {
    strings.push_back(key.ToString());
  }
  std::sort(strings.begin(), strings.end());
  return MakeNSString(absl::StrJoin(strings, ", "));
}

NSString *ToDocumentListString(const std::map<DocumentKey, TargetId> &map) {
  std::set<DocumentKey> keys;
  for (const auto &kv : map) {
    keys.insert(kv.first);
  }
  return ToDocumentListString(keys);
}

NSString *ToTargetIdListString(const ActiveTargetMap &map) {
  std::vector<model::TargetId> targetIds;
  targetIds.reserve(map.size());
  for (const auto &kv : map) {
    targetIds.push_back(kv.first);
  }
  std::sort(targetIds.begin(), targetIds.end());
  return MakeNSString(absl::StrJoin(targetIds, ", "));
}

}  // namespace

@interface FSTSpecTests ()
@property(nonatomic, strong, nullable) FSTSyncEngineTestDriver *driver;

@end

@implementation FSTSpecTests {
  BOOL _gcEnabled;
  size_t _maxConcurrentLimboResolutions;
  BOOL _networkEnabled;
  FSTUserDataReader *_reader;
  std::shared_ptr<util::Executor> user_executor_;
}

#define FSTAbstractMethodException()                                                               \
  [NSException exceptionWithName:NSInternalInconsistencyException                                  \
                          reason:[NSString stringWithFormat:@"You must override %s in a subclass", \
                                                            __func__]                              \
                        userInfo:nil];

- (std::unique_ptr<Persistence>)persistenceWithGCEnabled:(__unused BOOL)GCEnabled {
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
  _reader = FSTTestUserDataReader();
  std::unique_ptr<util::Executor> user_executor = util::Executor::CreateSerial("user executor");
  user_executor_ = absl::ShareUniquePtr(std::move(user_executor));

  // Store GCEnabled so we can re-use it in doRestart.
  NSNumber *GCEnabled = config[@"useGarbageCollection"];
  _gcEnabled = [GCEnabled boolValue];
  NSNumber *maxConcurrentLimboResolutions = config[@"maxConcurrentLimboResolutions"];
  _maxConcurrentLimboResolutions = (maxConcurrentLimboResolutions == nil)
                                       ? std::numeric_limits<size_t>::max()
                                       : maxConcurrentLimboResolutions.unsignedIntValue;
  NSNumber *numClients = config[@"numClients"];
  if (numClients) {
    XCTAssertEqualObjects(numClients, @1, @"The iOS client does not support multi-client tests");
  }
  std::unique_ptr<Persistence> persistence = [self persistenceWithGCEnabled:_gcEnabled];
  self.driver =
      [[FSTSyncEngineTestDriver alloc] initWithPersistence:std::move(persistence)
                                               initialUser:User::Unauthenticated()
                                         outstandingWrites:{}
                             maxConcurrentLimboResolutions:_maxConcurrentLimboResolutions];
  [self.driver start];
}

- (void)tearDownForSpec {
  [self.driver shutdown];

  // Help ARC realize that everything here can be collected earlier.
  _driver = nil;
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
      NSString *limitType = queryDict[@"limitType"];
      if ([limitType isEqualToString:@"LimitToFirst"]) {
        query = query.WithLimitToFirst(limit);
      } else {
        query = query.WithLimitToLast(limit);
      }
    }

    if (queryDict[@"filters"]) {
      NSArray<NSArray<id> *> *filters = queryDict[@"filters"];
      for (NSArray<id> *filter in filters) {
        std::string key = util::MakeString(filter[0]);
        std::string op = util::MakeString(filter[1]);
        Message<google_firestore_v1_Value> value = [_reader parsedQueryValue:filter[2]];
        query = query.AddingFilter(Filter(key, op, std::move(value)));
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

  XCTAssert([jsonDoc[@"key"] isKindOfClass:[NSString class]]);
  Message<google_firestore_v1_Value> data = [_reader parsedQueryValue:jsonDoc[@"value"]];
  MutableDocument doc =
      Doc(util::MakeString((NSString *)jsonDoc[@"key"]), version.longLongValue, std::move(data));
  if ([options[@"hasLocalMutations"] boolValue] == YES) {
    doc.SetHasLocalMutations();
  } else if ([options[@"hasCommittedMutations"] boolValue] == YES) {
    doc.SetHasCommittedMutations();
  }
  return DocumentViewChange{std::move(doc), type};
}

#pragma mark - Methods for doing the steps of the spec test.

- (void)doListen:(NSDictionary *)listenSpec {
  Query query = [self parseQuery:listenSpec[@"query"]];
  TargetId actualID = [self.driver addUserListenerWithQuery:std::move(query)];

  TargetId expectedID = [listenSpec[@"targetId"] intValue];
  XCTAssertEqual(actualID, expectedID, @"targetID assigned to listen");
}

- (void)doUnlisten:(NSArray *)unlistenSpec {
  Query query = [self parseQuery:unlistenSpec[1]];
  [self.driver removeUserListenerWithQuery:std::move(query)];
}

- (void)doLoadBundle:(NSString *)bundleJson {
  const auto &database_info = [self.driver databaseInfo];
  BundleSerializer bundle_serializer(remote::Serializer(database_info.database_id()));
  auto data = util::MakeString(bundleJson);
  auto bundle = absl::make_unique<util::ByteStreamCpp>(
      absl::make_unique<std::stringstream>(std::stringstream(data)));
  auto reader = std::make_shared<BundleReader>(std::move(bundle_serializer), std::move(bundle));
  auto task = std::make_shared<LoadBundleTask>(user_executor_);
  [self.driver loadBundleWithReader:std::move(reader) task:std::move(task)];
}

- (void)doSet:(NSArray *)setSpec {
  [self.driver writeUserMutation:FSTTestSetMutation(setSpec[0], setSpec[1])];
}

- (void)doPatch:(NSArray *)patchSpec {
  [self.driver writeUserMutation:FSTTestPatchMutation(patchSpec[0], patchSpec[1], {})];
}

- (void)doDelete:(NSString *)key {
  [self.driver writeUserMutation:FSTTestDeleteMutation(key)];
}

- (void)doWaitForPendingWrites {
  [self.driver waitForPendingWrites];
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
    MutableDocument doc;
    if (value) {
      doc = MutableDocument::FoundDocument(key, version, *std::move(value));
    } else {
      doc = MutableDocument::NoDocument(key, version);
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

  MutationResult mutationResult(version, Message<google_firestore_v1_ArrayValue>{});
  std::vector<MutationResult> mutationResults;
  mutationResults.emplace_back(std::move(mutationResult));
  [self.driver receiveWriteAckWithVersion:version mutationResults:std::move(mutationResults)];
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
  self.driver =
      [[FSTSyncEngineTestDriver alloc] initWithPersistence:std::move(persistence)
                                               initialUser:currentUser
                                         outstandingWrites:outstandingWrites
                             maxConcurrentLimboResolutions:_maxConcurrentLimboResolutions];
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
  } else if (step[@"loadBundle"]) {
    [self doLoadBundle:step[@"loadBundle"]];
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
  } else if (step[@"waitForPendingWrites"]) {
    [self doWaitForPendingWrites];
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
    XCTAssertEqual(events.count, 0u);
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
    if (expectedState[@"activeLimboDocs"]) {
      DocumentKeySet expectedActiveLimboDocuments;
      NSArray *docNames = expectedState[@"activeLimboDocs"];
      for (NSString *name in docNames) {
        expectedActiveLimboDocuments = expectedActiveLimboDocuments.insert(FSTTestDocKey(name));
      }
      // Update the expected active limbo documents
      [self.driver setExpectedActiveLimboDocuments:std::move(expectedActiveLimboDocuments)];
    }
    if (expectedState[@"enqueuedLimboDocs"]) {
      DocumentKeySet expectedEnqueuedLimboDocuments;
      NSArray *docNames = expectedState[@"enqueuedLimboDocs"];
      for (NSString *name in docNames) {
        expectedEnqueuedLimboDocuments = expectedEnqueuedLimboDocuments.insert(FSTTestDocKey(name));
      }
      // Update the expected enqueued limbo documents
      [self.driver setExpectedEnqueuedLimboDocuments:std::move(expectedEnqueuedLimboDocuments)];
    }
    if (expectedState[@"activeTargets"]) {
      __block ActiveTargetMap expectedActiveTargets;
      [expectedState[@"activeTargets"]
          enumerateKeysAndObjectsUsingBlock:^(NSString *targetIDString, NSDictionary *queryData,
                                              BOOL *) {
            TargetId targetID = [targetIDString intValue];
            NSArray *queriesJson = queryData[@"queries"];
            std::vector<TargetData> queries;
            for (id queryJson in queriesJson) {
              Query query = [self parseQuery:queryJson];
              // TODO(mcg): populate the purpose of the target once it's possible to encode that in
              // the spec tests. For now, hard-code that it's a listen despite the fact that it's
              // not always the right value.
              TargetData target_data(query.ToTarget(), targetID, 0, QueryPurpose::Listen);
              if ([queryData objectForKey:@"resumeToken"] != nil) {
                target_data = target_data.WithResumeToken(
                    MakeResumeToken(queryData[@"resumeToken"]), SnapshotVersion::None());
              } else {
                target_data = target_data.WithResumeToken(
                    ByteString(), [self parseVersion:queryData[@"readTime"]]);
              }
              queries.push_back(std::move(target_data));
            }
            expectedActiveTargets[targetID] = std::move(queries);
          }];
      [self.driver setExpectedActiveTargets:std::move(expectedActiveTargets)];
    }
  }

  // Always validate the we received the expected number of callbacks.
  [self validateUserCallbacks:expectedState];
  // Always validate that the expected limbo docs match the actual limbo docs.
  [self validateActiveLimboDocuments];
  [self validateEnqueuedLimboDocuments];
  // Always validate that the expected active targets match the actual active targets.
  [self validateActiveTargets];
}

- (void)validateWaitForPendingWritesEvents:(int)expectedWaitForPendingWritesEvents {
  XCTAssertEqual(expectedWaitForPendingWritesEvents, [self.driver waitForPendingWritesEvents]);
  [self.driver resetWaitForPendingWritesEvents];
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
    XCTAssertEqual([actualAcknowledgedDocs count], 0u);
    XCTAssertEqual([actualRejectedDocs count], 0u);
  }
}

- (void)validateActiveLimboDocuments {
  // Make a copy so it can modified while checking against the expected limbo docs.
  std::map<DocumentKey, TargetId> actualLimboDocs = self.driver.activeLimboDocumentResolutions;

  // Validate that each active limbo doc has an expected active target
  for (const auto &kv : actualLimboDocs) {
    const auto &expected = [self.driver expectedActiveTargets];
    XCTAssertTrue(expected.find(kv.second) != expected.end(),
                  @"Found limbo doc %s, but its target ID %d was not in the "
                  @"set of expected active target IDs %@",
                  kv.first.ToString().c_str(), kv.second, ToTargetIdListString(expected));
  }

  for (const DocumentKey &expectedLimboDoc : self.driver.expectedActiveLimboDocuments) {
    XCTAssert(actualLimboDocs.find(expectedLimboDoc) != actualLimboDocs.end(),
              @"Expected doc to be in limbo, but was not: %s", expectedLimboDoc.ToString().c_str());
    actualLimboDocs.erase(expectedLimboDoc);
  }

  XCTAssertTrue(actualLimboDocs.empty(), @"Unexpected active docs in limbo: %@",
                ToDocumentListString(actualLimboDocs));
}

- (void)validateEnqueuedLimboDocuments {
  std::set<DocumentKey> actualLimboDocs;
  for (const auto &key : self.driver.enqueuedLimboDocumentResolutions) {
    actualLimboDocs.insert(key);
  }
  std::set<DocumentKey> expectedLimboDocs;
  for (const auto &key : self.driver.expectedEnqueuedLimboDocuments) {
    expectedLimboDocs.insert(key);
  }

  for (const auto &key : actualLimboDocs) {
    XCTAssertTrue(expectedLimboDocs.find(key) != expectedLimboDocs.end(),
                  @"Found enqueued limbo doc %s, but it was not in the set of "
                  @"expected enqueued limbo documents (%@)",
                  key.ToString().c_str(), ToDocumentListString(expectedLimboDocs));
  }

  for (const auto &key : expectedLimboDocs) {
    XCTAssertTrue(actualLimboDocs.find(key) != actualLimboDocs.end(),
                  @"Expected doc %s to be enqueued for limbo resolution, "
                  @"but it was not in the queue (%@)",
                  key.ToString().c_str(), ToDocumentListString(actualLimboDocs));
  }
}

- (void)validateActiveTargets {
  if (!_networkEnabled) {
    return;
  }

  // Create a copy so we can modify it below
  std::unordered_map<TargetId, TargetData> actualTargets = [self.driver activeTargets];

  for (const auto &kv : [self.driver expectedActiveTargets]) {
    TargetId targetID = kv.first;
    const std::vector<TargetData> &queries = kv.second;
    const TargetData &targetData = queries[0];

    auto found = actualTargets.find(targetID);
    XCTAssertNotEqual(found, actualTargets.end(), @"Expected active target not found: %s",
                      targetData.ToString().c_str());

    // TODO(mcg): validate the purpose of the target once it's possible to encode that in the
    // spec tests. For now, only validate properties that can be validated.
    // XCTAssertEqualObjects(actualTargets[targetID], TargetData);

    const TargetData &actual = found->second;
    XCTAssertEqual(actual.target(), targetData.target());
    XCTAssertEqual(actual.target_id(), targetData.target_id());
    XCTAssertEqual(actual.snapshot_version(), targetData.snapshot_version());
    XCTAssertEqual(actual.resume_token(), targetData.resume_token());

    actualTargets.erase(targetID);
  }

  XCTAssertTrue(actualTargets.empty(), "Unexpected active targets: %s",
                util::ToString(actualTargets).c_str());
}

- (void)runSpecTestSteps:(NSArray *)steps config:(NSDictionary *)config {
  @autoreleasepool {
    @try {
      [self setUpForSpecWithConfig:config];
      for (NSDictionary *step in steps) {
        LOG_DEBUG("Doing step %s", step);
        [self doStep:step];
        [self validateExpectedSnapshotEvents:step[@"expectedSnapshotEvents"]];
        [self validateExpectedState:step[@"expectedState"]];
        int expectedSnapshotsInSyncEvents = [step[@"expectedSnapshotsInSyncEvents"] intValue];
        [self validateSnapshotsInSyncEvents:expectedSnapshotsInSyncEvents];
        int expectedWaitForPendingWritesEvents =
            [step[@"expectedWaitForPendingWritesEvents"] intValue];
        [self validateWaitForPendingWritesEvents:expectedWaitForPendingWritesEvents];
      }
      [self.driver validateUsage];
    } @finally {
      // Ensure that the driver is torn down even if the test is failing due to a thrown exception
      // so that any resources held by the driver are released. This is important when the driver is
      // backed by LevelDB because LevelDB locks its database. If -tearDownForSpec were not called
      // after an exception then subsequent attempts to open the LevelDB will fail, making it harder
      // to zero in on the spec tests as a culprit.
      [self tearDownForSpec];
    }
  }
}

#pragma mark - The actual test methods.

- (void)testSpecTests {
  if ([self isTestBaseClass]) return;

  // Enumerate the .json files containing the spec tests.
  NSMutableArray<NSString *> *specFiles = [NSMutableArray array];
  NSMutableArray<NSDictionary *> *parsedSpecs = [NSMutableArray array];
  BOOL exclusiveMode = NO;

  // TODO(wilhuff): Fix this when running spec tests using a real device
  auto source_file = Path::FromUtf8(__FILE__);
  Path json_ext = Path::FromUtf8(".json");
  auto spec_dir = source_file.Dirname();
  auto json_dir = spec_dir.AppendUtf8("json");

  auto iter = util::DirectoryIterator::Create(json_dir);
  for (; iter->Valid(); iter->Next()) {
    Path entry = iter->file();
    if (!entry.HasExtension(json_ext)) {
      continue;
    }

    // Read and parse the JSON from the file.
    NSString *path = entry.ToNSString();
    NSData *json = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(json);
    NSError *error = nil;
    id _Nullable parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:&error];
    XCTAssertNil(error, @"%@", error);
    XCTAssertTrue([parsed isKindOfClass:[NSDictionary class]]);
    NSDictionary *testDict = (NSDictionary *)parsed;

    exclusiveMode = exclusiveMode || [self anyTestsAreMarkedExclusive:testDict];
    [specFiles addObject:entry.Basename().ToNSString()];
    [parsedSpecs addObject:testDict];
  }

  NSString *testNameFilterFromEnv = NSProcessInfo.processInfo.environment[kTestFilterEnvKey];
  NSRegularExpression *testNameFilter;
  if (testNameFilterFromEnv.length == 0) {
    testNameFilter = nil;
  } else {
    exclusiveMode = YES;
    NSError *error;
    testNameFilter =
        [NSRegularExpression regularExpressionWithPattern:testNameFilterFromEnv
                                                  options:NSRegularExpressionAnchorsMatchLines
                                                    error:&error];
    XCTAssertNotNil(testNameFilter, @"Invalid regular expression: %@ (%@)", testNameFilterFromEnv,
                    error);
  }

  // Now iterate over them and run them.
  __block int testPassCount = 0;
  __block int testSkipCount = 0;
  __block bool ranAtLeastOneTest = NO;
  for (NSUInteger i = 0; i < specFiles.count; i++) {
    NSLog(@"Spec test file: %@", specFiles[i]);
    // Iterate over the tests in the file and run them.
    [parsedSpecs[i] enumerateKeysAndObjectsUsingBlock:^(id, id obj, BOOL *) {
      XCTAssertTrue([obj isKindOfClass:[NSDictionary class]]);
      NSDictionary *testDescription = (NSDictionary *)obj;
      NSString *describeName = testDescription[@"describeName"];
      NSString *itName = testDescription[@"itName"];
      NSString *name = [NSString stringWithFormat:@"%@ %@", describeName, itName];
      NSDictionary *config = testDescription[@"config"];
      NSArray *steps = testDescription[@"steps"];
      NSArray<NSString *> *tags = testDescription[@"tags"];

      BOOL runTest;
      if (![self shouldRunWithTags:tags]) {
        runTest = NO;
      } else if (!exclusiveMode) {
        runTest = YES;
      } else if ([tags indexOfObject:kExclusiveTag] != NSNotFound) {
        runTest = YES;
      } else if (testNameFilter != nil) {
        NSRange testNameFilterMatchRange =
            [testNameFilter rangeOfFirstMatchInString:name
                                              options:0
                                                range:NSMakeRange(0, [name length])];
        runTest = !NSEqualRanges(testNameFilterMatchRange, NSMakeRange(NSNotFound, 0));
      } else {
        runTest = NO;
      }

      if (runTest) {
        NSLog(@"  Spec test: %@", name);
        [self runSpecTestSteps:steps config:config];
        ranAtLeastOneTest = YES;
        ++testPassCount;
      } else {
        ++testSkipCount;
        NSLog(@"  [SKIPPED] Spec test: %@", name);
        NSString *comment = testDescription[@"comment"];
        if (comment) {
          NSLog(@"    %@", comment);
        }
      }
    }];
  }
  NSLog(@"%@ completed; pass=%d skip=%d", NSStringFromClass([self class]), testPassCount,
        testSkipCount);
  XCTAssertTrue(ranAtLeastOneTest);
}

- (BOOL)anyTestsAreMarkedExclusive:(NSDictionary *)tests {
  __block BOOL found = NO;
  [tests enumerateKeysAndObjectsUsingBlock:^(id, id obj, BOOL *stop) {
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
