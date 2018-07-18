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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSyncEngine.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

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
@property(nonatomic, strong, nullable, readwrite) FSTViewSnapshot *viewSnapshot;
@property(nonatomic, assign, readwrite) FSTTargetID targetID;
@property(nonatomic, strong, readonly) NSMutableArray<FSTQueryListener *> *listeners;
@end

@implementation FSTQueryListenersInfo
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
@property(nonatomic, strong, nullable) FSTViewSnapshot *snapshot;

@property(nonatomic, strong, readonly) FSTListenOptions *options;

/**
 * Initial snapshots (e.g. from cache) may not be propagated to the FSTViewSnapshotHandler.
 * This flag is set to YES once we've actually raised an event.
 */
@property(nonatomic, assign, readwrite) BOOL raisedInitialEvent;

/** The last online state this query listener got. */
@property(nonatomic, assign, readwrite) FSTOnlineState onlineState;

/** The FSTViewSnapshotHandler associated with this query listener. */
@property(nonatomic, copy, nullable) FSTViewSnapshotHandler viewSnapshotHandler;

@end

@implementation FSTQueryListener

- (instancetype)initWithQuery:(FSTQuery *)query
                      options:(FSTListenOptions *)options
          viewSnapshotHandler:(FSTViewSnapshotHandler)viewSnapshotHandler {
  if (self = [super init]) {
    _query = query;
    _options = options;
    _viewSnapshotHandler = viewSnapshotHandler;
    _raisedInitialEvent = NO;
  }
  return self;
}

- (void)queryDidChangeViewSnapshot:(FSTViewSnapshot *)snapshot {
  HARD_ASSERT(snapshot.documentChanges.count > 0 || snapshot.syncStateChanged,
              "We got a new snapshot with no changes?");

  if (!self.options.includeDocumentMetadataChanges) {
    // Remove the metadata-only changes.
    NSMutableArray<FSTDocumentViewChange *> *changes = [NSMutableArray array];
    for (FSTDocumentViewChange *change in snapshot.documentChanges) {
      if (change.type != FSTDocumentViewChangeTypeMetadata) {
        [changes addObject:change];
      }
    }
    snapshot = [[FSTViewSnapshot alloc] initWithQuery:snapshot.query
                                            documents:snapshot.documents
                                         oldDocuments:snapshot.oldDocuments
                                      documentChanges:changes
                                            fromCache:snapshot.fromCache
                                     hasPendingWrites:snapshot.hasPendingWrites
                                     syncStateChanged:snapshot.syncStateChanged];
  }

  if (!self.raisedInitialEvent) {
    if ([self shouldRaiseInitialEventForSnapshot:snapshot onlineState:self.onlineState]) {
      [self raiseInitialEventForSnapshot:snapshot];
    }
  } else if ([self shouldRaiseEventForSnapshot:snapshot]) {
    self.viewSnapshotHandler(snapshot, nil);
  }

  self.snapshot = snapshot;
}

- (void)queryDidError:(NSError *)error {
  self.viewSnapshotHandler(nil, error);
}

- (void)applyChangedOnlineState:(FSTOnlineState)onlineState {
  self.onlineState = onlineState;
  if (self.snapshot && !self.raisedInitialEvent &&
      [self shouldRaiseInitialEventForSnapshot:self.snapshot onlineState:onlineState]) {
    [self raiseInitialEventForSnapshot:self.snapshot];
  }
}

- (BOOL)shouldRaiseInitialEventForSnapshot:(FSTViewSnapshot *)snapshot
                               onlineState:(FSTOnlineState)onlineState {
  HARD_ASSERT(!self.raisedInitialEvent,
              "Determining whether to raise initial event, but already had first event.");

  // Always raise the first event when we're synced
  if (!snapshot.fromCache) {
    return YES;
  }

  // NOTE: We consider OnlineState.Unknown as online (it should become Offline or Online if we
  // wait long enough).
  BOOL maybeOnline = onlineState != FSTOnlineStateOffline;
  // Don't raise the event if we're online, aren't synced yet (checked
  // above) and are waiting for a sync.
  if (self.options.waitForSyncWhenOnline && maybeOnline) {
    HARD_ASSERT(snapshot.fromCache, "Waiting for sync, but snapshot is not from cache.");
    return NO;
  }

  // Raise data from cache if we have any documents or we are offline
  return !snapshot.documents.isEmpty || onlineState == FSTOnlineStateOffline;
}

- (BOOL)shouldRaiseEventForSnapshot:(FSTViewSnapshot *)snapshot {
  // We don't need to handle includeDocumentMetadataChanges here because the Metadata only changes
  // have already been stripped out if needed. At this point the only changes we will see are the
  // ones we should propagate.
  if (snapshot.documentChanges.count > 0) {
    return YES;
  }

  BOOL hasPendingWritesChanged =
      self.snapshot && self.snapshot.hasPendingWrites != snapshot.hasPendingWrites;
  if (snapshot.syncStateChanged || hasPendingWritesChanged) {
    return self.options.includeQueryMetadataChanges;
  }

  // Generally we should have hit one of the cases above, but it's possible to get here if there
  // were only metadata docChanges and they got stripped out.
  return NO;
}

- (void)raiseInitialEventForSnapshot:(FSTViewSnapshot *)snapshot {
  HARD_ASSERT(!self.raisedInitialEvent, "Trying to raise initial events for second time");
  snapshot = [[FSTViewSnapshot alloc]
         initWithQuery:snapshot.query
             documents:snapshot.documents
          oldDocuments:[FSTDocumentSet documentSetWithComparator:snapshot.query.comparator]
       documentChanges:[FSTQueryListener getInitialViewChangesFor:snapshot]
             fromCache:snapshot.fromCache
      hasPendingWrites:snapshot.hasPendingWrites
      syncStateChanged:YES];
  self.raisedInitialEvent = YES;
  self.viewSnapshotHandler(snapshot, nil);
}

+ (NSArray<FSTDocumentViewChange *> *)getInitialViewChangesFor:(FSTViewSnapshot *)snapshot {
  NSMutableArray<FSTDocumentViewChange *> *result = [NSMutableArray array];
  for (FSTDocument *doc in snapshot.documents.documentEnumerator) {
    [result addObject:[FSTDocumentViewChange changeWithDocument:doc
                                                           type:FSTDocumentViewChangeTypeAdded]];
  }
  return result;
}

@end

#pragma mark - FSTEventManager

@interface FSTEventManager () <FSTSyncEngineDelegate>

- (instancetype)initWithSyncEngine:(FSTSyncEngine *)syncEngine NS_DESIGNATED_INITIALIZER;

@property(nonatomic, strong, readonly) FSTSyncEngine *syncEngine;
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTQuery *, FSTQueryListenersInfo *> *queries;
@property(nonatomic, assign) FSTOnlineState onlineState;

@end

@implementation FSTEventManager

+ (instancetype)eventManagerWithSyncEngine:(FSTSyncEngine *)syncEngine {
  return [[FSTEventManager alloc] initWithSyncEngine:syncEngine];
}

- (instancetype)initWithSyncEngine:(FSTSyncEngine *)syncEngine {
  if (self = [super init]) {
    _syncEngine = syncEngine;
    _queries = [NSMutableDictionary dictionary];

    _syncEngine.delegate = self;
  }
  return self;
}

- (FSTTargetID)addListener:(FSTQueryListener *)listener {
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

  if (queryInfo.viewSnapshot) {
    [listener queryDidChangeViewSnapshot:queryInfo.viewSnapshot];
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

- (void)handleViewSnapshots:(NSArray<FSTViewSnapshot *> *)viewSnapshots {
  for (FSTViewSnapshot *viewSnapshot in viewSnapshots) {
    FSTQuery *query = viewSnapshot.query;
    FSTQueryListenersInfo *queryInfo = self.queries[query];
    if (queryInfo) {
      for (FSTQueryListener *listener in queryInfo.listeners) {
        [listener queryDidChangeViewSnapshot:viewSnapshot];
      }
      queryInfo.viewSnapshot = viewSnapshot;
    }
  }
}

- (void)handleError:(NSError *)error forQuery:(FSTQuery *)query {
  FSTQueryListenersInfo *queryInfo = self.queries[query];
  if (queryInfo) {
    for (FSTQueryListener *listener in queryInfo.listeners) {
      [listener queryDidError:error];
    }
  }

  // Remove all listeners. NOTE: We don't need to call [FSTSyncEngine stopListening] after an error.
  [self.queries removeObjectForKey:query];
}

- (void)applyChangedOnlineState:(FSTOnlineState)onlineState {
  self.onlineState = onlineState;
  for (FSTQueryListenersInfo *info in self.queries.objectEnumerator) {
    for (FSTQueryListener *listener in info.listeners) {
      [listener applyChangedOnlineState:onlineState];
    }
  }
}

@end

NS_ASSUME_NONNULL_END
