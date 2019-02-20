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

#import "Firestore/Source/Core/FSTEventManager.h"

#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/types/optional.h"

using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::core::ViewSnapshotHandler;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::TargetId;
using firebase::firestore::util::Status;
using firebase::firestore::util::MakeStatus;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTListenOptions

@implementation FSTListenOptions

+ (instancetype)defaultOptions {
  static FSTListenOptions *defaultOptions;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    defaultOptions = [[FSTListenOptions alloc] initWithIncludeQueryMetadataChanges:NO
                                                    includeDocumentMetadataChanges:NO
                                                             waitForSyncWhenOnline:NO];
  });
  return defaultOptions;
}

- (instancetype)initWithIncludeQueryMetadataChanges:(BOOL)includeQueryMetadataChanges
                     includeDocumentMetadataChanges:(BOOL)includeDocumentMetadataChanges
                              waitForSyncWhenOnline:(BOOL)waitForSyncWhenOnline {
  if (self = [super init]) {
    _includeQueryMetadataChanges = includeQueryMetadataChanges;
    _includeDocumentMetadataChanges = includeDocumentMetadataChanges;
    _waitForSyncWhenOnline = waitForSyncWhenOnline;
  }
  return self;
}

- (instancetype)init {
  HARD_FAIL("FSTListenOptions init not supported");
  return nil;
}

@end

#pragma mark - FSTQueryListenersInfo

/**
 * Holds the listeners and the last received ViewSnapshot for a query being tracked by
 * EventManager.
 */
@interface FSTQueryListenersInfo : NSObject
@property(nonatomic, assign, readwrite) TargetId targetID;
@property(nonatomic, strong, readonly) NSMutableArray<FSTQueryListener *> *listeners;

- (const absl::optional<ViewSnapshot> &)viewSnapshot;
- (void)setViewSnapshot:(const absl::optional<ViewSnapshot> &)snapshot;

@end

@implementation FSTQueryListenersInfo {
  absl::optional<ViewSnapshot> _viewSnapshot;
}

- (const absl::optional<ViewSnapshot> &)viewSnapshot {
  return _viewSnapshot;
}
- (void)setViewSnapshot:(const absl::optional<ViewSnapshot> &)snapshot {
  _viewSnapshot = snapshot;
}

- (instancetype)init {
  if (self = [super init]) {
    _listeners = [NSMutableArray array];
  }
  return self;
}

@end

#pragma mark - FSTQueryListener

@interface FSTQueryListener ()

/** The last received view snapshot. */
- (const absl::optional<ViewSnapshot> &)snapshot;

@property(nonatomic, strong, readonly) FSTListenOptions *options;

/**
 * Initial snapshots (e.g. from cache) may not be propagated to the ViewSnapshotHandler.
 * This flag is set to YES once we've actually raised an event.
 */
@property(nonatomic, assign, readwrite) BOOL raisedInitialEvent;

/** The last online state this query listener got. */
@property(nonatomic, assign, readwrite) OnlineState onlineState;

@end

@implementation FSTQueryListener {
  absl::optional<ViewSnapshot> _snapshot;

  /** The ViewSnapshotHandler associated with this query listener. */
  ViewSnapshotHandler _viewSnapshotHandler;
}

- (instancetype)initWithQuery:(FSTQuery *)query
                      options:(FSTListenOptions *)options
          viewSnapshotHandler:(ViewSnapshotHandler &&)viewSnapshotHandler {
  if (self = [super init]) {
    _query = query;
    _options = options;
    _viewSnapshotHandler = std::move(viewSnapshotHandler);
    _raisedInitialEvent = NO;
  }
  return self;
}

- (const absl::optional<ViewSnapshot> &)snapshot {
  return _snapshot;
}

- (void)queryDidChangeViewSnapshot:(ViewSnapshot)snapshot {
  HARD_ASSERT(!snapshot.document_changes().empty() || snapshot.sync_state_changed(),
              "We got a new snapshot with no changes?");

  if (!self.options.includeDocumentMetadataChanges) {
    // Remove the metadata-only changes.
    std::vector<DocumentViewChange> changes;
    for (const DocumentViewChange &change : snapshot.document_changes()) {
      if (change.type() != DocumentViewChange::Type::kMetadata) {
        changes.push_back(change);
      }
    }

    snapshot = ViewSnapshot{snapshot.query(),
                            snapshot.documents(),
                            snapshot.old_documents(),
                            std::move(changes),
                            snapshot.mutated_keys(),
                            snapshot.from_cache(),
                            snapshot.sync_state_changed(),
                            /*excludes_metadata_changes=*/true};
  }

  if (!self.raisedInitialEvent) {
    if ([self shouldRaiseInitialEventForSnapshot:snapshot onlineState:self.onlineState]) {
      [self raiseInitialEventForSnapshot:snapshot];
    }
  } else if ([self shouldRaiseEventForSnapshot:snapshot]) {
    _viewSnapshotHandler(snapshot);
  }

  _snapshot = std::move(snapshot);
}

- (void)queryDidError:(const Status &)error {
  _viewSnapshotHandler(error);
}

- (void)applyChangedOnlineState:(OnlineState)onlineState {
  self.onlineState = onlineState;
  if (_snapshot.has_value() && !self.raisedInitialEvent &&
      [self shouldRaiseInitialEventForSnapshot:_snapshot.value() onlineState:onlineState]) {
    [self raiseInitialEventForSnapshot:_snapshot.value()];
  }
}

- (BOOL)shouldRaiseInitialEventForSnapshot:(const ViewSnapshot &)snapshot
                               onlineState:(OnlineState)onlineState {
  HARD_ASSERT(!self.raisedInitialEvent,
              "Determining whether to raise initial event, but already had first event.");

  // Always raise the first event when we're synced
  if (!snapshot.from_cache()) {
    return YES;
  }

  // NOTE: We consider OnlineState.Unknown as online (it should become Offline or Online if we
  // wait long enough).
  BOOL maybeOnline = onlineState != OnlineState::Offline;
  // Don't raise the event if we're online, aren't synced yet (checked
  // above) and are waiting for a sync.
  if (self.options.waitForSyncWhenOnline && maybeOnline) {
    HARD_ASSERT(snapshot.from_cache(), "Waiting for sync, but snapshot is not from cache.");
    return NO;
  }

  // Raise data from cache if we have any documents or we are offline
  return !snapshot.documents().isEmpty || onlineState == OnlineState::Offline;
}

- (BOOL)shouldRaiseEventForSnapshot:(const ViewSnapshot &)snapshot {
  // We don't need to handle includeDocumentMetadataChanges here because the Metadata only changes
  // have already been stripped out if needed. At this point the only changes we will see are the
  // ones we should propagate.
  if (!snapshot.document_changes().empty()) {
    return YES;
  }

  BOOL hasPendingWritesChanged = _snapshot.has_value() && _snapshot.value().has_pending_writes() !=
                                                              snapshot.has_pending_writes();
  if (snapshot.sync_state_changed() || hasPendingWritesChanged) {
    return self.options.includeQueryMetadataChanges;
  }

  // Generally we should have hit one of the cases above, but it's possible to get here if there
  // were only metadata docChanges and they got stripped out.
  return NO;
}

- (void)raiseInitialEventForSnapshot:(const ViewSnapshot &)snapshot {
  HARD_ASSERT(!self.raisedInitialEvent, "Trying to raise initial events for second time");
  ViewSnapshot modifiedSnapshot = ViewSnapshot::FromInitialDocuments(
      snapshot.query(), snapshot.documents(), snapshot.mutated_keys(), snapshot.from_cache(),
      snapshot.excludes_metadata_changes());
  self.raisedInitialEvent = YES;
  _viewSnapshotHandler(modifiedSnapshot);
}

@end

#pragma mark - FSTEventManager

@interface FSTEventManager () <FSTSyncEngineDelegate>

- (instancetype)initWithSyncEngine:(FSTSyncEngine *)syncEngine NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTQuery *, FSTQueryListenersInfo *> *queries;
@property(nonatomic, assign) OnlineState onlineState;

@end

@implementation FSTEventManager

+ (instancetype)eventManagerWithSyncEngine:(FSTSyncEngine *)syncEngine {
  return [[FSTEventManager alloc] initWithSyncEngine:syncEngine];
}

- (instancetype)initWithSyncEngine:(FSTSyncEngine *)syncEngine {
  if (self = [super init]) {
    _syncEngine = syncEngine;
    _queries = [NSMutableDictionary dictionary];

    _syncEngine.syncEngineDelegate = self;
  }
  return self;
}

- (TargetId)addListener:(FSTQueryListener *)listener {
  FSTQuery *query = listener.query;
  BOOL firstListen = NO;

  FSTQueryListenersInfo *queryInfo = self.queries[query];
  if (!queryInfo) {
    firstListen = YES;
    queryInfo = [[FSTQueryListenersInfo alloc] init];
    self.queries[query] = queryInfo;
  }
  [queryInfo.listeners addObject:listener];

  [listener applyChangedOnlineState:self.onlineState];

  if (queryInfo.viewSnapshot.has_value()) {
    [listener queryDidChangeViewSnapshot:queryInfo.viewSnapshot.value()];
  }

  if (firstListen) {
    queryInfo.targetID = [self.syncEngine listenToQuery:query];
  }
  return queryInfo.targetID;
}

- (void)removeListener:(FSTQueryListener *)listener {
  FSTQuery *query = listener.query;
  BOOL lastListen = NO;

  FSTQueryListenersInfo *queryInfo = self.queries[query];
  if (queryInfo) {
    [queryInfo.listeners removeObject:listener];
    lastListen = (queryInfo.listeners.count == 0);
  }

  if (lastListen) {
    [self.queries removeObjectForKey:query];
    [self.syncEngine stopListeningToQuery:query];
  }
}

- (void)handleViewSnapshots:(std::vector<ViewSnapshot> &&)viewSnapshots {
  for (ViewSnapshot &viewSnapshot : viewSnapshots) {
    FSTQuery *query = viewSnapshot.query();
    FSTQueryListenersInfo *queryInfo = self.queries[query];
    if (queryInfo) {
      for (FSTQueryListener *listener in queryInfo.listeners) {
        [listener queryDidChangeViewSnapshot:viewSnapshot];
      }
      [queryInfo setViewSnapshot:std::move(viewSnapshot)];
    }
  }
}

- (void)handleError:(NSError *)error forQuery:(FSTQuery *)query {
  FSTQueryListenersInfo *queryInfo = self.queries[query];
  if (queryInfo) {
    for (FSTQueryListener *listener in queryInfo.listeners) {
      [listener queryDidError:MakeStatus(error)];
    }
  }

  // Remove all listeners. NOTE: We don't need to call [FSTSyncEngine stopListening] after an error.
  [self.queries removeObjectForKey:query];
}

- (void)applyChangedOnlineState:(OnlineState)onlineState {
  self.onlineState = onlineState;
  for (FSTQueryListenersInfo *info in self.queries.objectEnumerator) {
    for (FSTQueryListener *listener in info.listeners) {
      [listener applyChangedOnlineState:onlineState];
    }
  }
}

@end

NS_ASSUME_NONNULL_END
