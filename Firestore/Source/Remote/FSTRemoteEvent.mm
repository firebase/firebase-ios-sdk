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

#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#include <map>
#include <utility>

#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTLogger.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTargetMapping

@interface FSTTargetMapping ()

/** Private mutator method to add a document key to the mapping */
- (void)addDocumentKey:(const DocumentKey &)documentKey;

/** Private mutator method to remove a document key from the mapping */
- (void)removeDocumentKey:(const DocumentKey &)documentKey;

@end

@implementation FSTTargetMapping

- (void)addDocumentKey:(const DocumentKey &)documentKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)removeDocumentKey:(const DocumentKey &)documentKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

@end

#pragma mark - FSTResetMapping

@interface FSTResetMapping ()
@property(nonatomic, strong) FSTDocumentKeySet *documents;
@end

@implementation FSTResetMapping

+ (instancetype)mappingWithDocuments:(NSArray<FSTDocument *> *)documents {
  FSTResetMapping *mapping = [[FSTResetMapping alloc] init];
  for (FSTDocument *doc in documents) {
    mapping.documents = [mapping.documents setByAddingObject:doc.key];
  }
  return mapping;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _documents = [FSTDocumentKeySet keySet];
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTResetMapping class]]) {
    return NO;
  }

  FSTResetMapping *otherMapping = (FSTResetMapping *)other;
  return [self.documents isEqual:otherMapping.documents];
}

- (NSUInteger)hash {
  return self.documents.hash;
}

- (void)addDocumentKey:(const DocumentKey &)documentKey {
  self.documents = [self.documents setByAddingObject:documentKey];
}

- (void)removeDocumentKey:(const DocumentKey &)documentKey {
  self.documents = [self.documents setByRemovingObject:documentKey];
}

@end

#pragma mark - FSTUpdateMapping

@interface FSTUpdateMapping ()
@property(nonatomic, strong) FSTDocumentKeySet *addedDocuments;
@property(nonatomic, strong) FSTDocumentKeySet *removedDocuments;
@end

@implementation FSTUpdateMapping

+ (FSTUpdateMapping *)mappingWithAddedDocuments:(NSArray<FSTDocument *> *)added
                               removedDocuments:(NSArray<FSTDocument *> *)removed {
  FSTUpdateMapping *mapping = [[FSTUpdateMapping alloc] init];
  for (FSTDocument *doc in added) {
    mapping.addedDocuments = [mapping.addedDocuments setByAddingObject:doc.key];
  }
  for (FSTDocument *doc in removed) {
    mapping.removedDocuments = [mapping.removedDocuments setByAddingObject:doc.key];
  }
  return mapping;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _addedDocuments = [FSTDocumentKeySet keySet];
    _removedDocuments = [FSTDocumentKeySet keySet];
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTUpdateMapping class]]) {
    return NO;
  }

  FSTUpdateMapping *otherMapping = (FSTUpdateMapping *)other;
  return [self.addedDocuments isEqual:otherMapping.addedDocuments] &&
         [self.removedDocuments isEqual:otherMapping.removedDocuments];
}

- (NSUInteger)hash {
  return self.addedDocuments.hash * 31 + self.removedDocuments.hash;
}

- (FSTDocumentKeySet *)applyTo:(FSTDocumentKeySet *)keys {
  __block FSTDocumentKeySet *result = keys;
  [self.addedDocuments enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    result = [result setByAddingObject:key];
  }];
  [self.removedDocuments enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    result = [result setByRemovingObject:key];
  }];
  return result;
}

- (void)addDocumentKey:(const DocumentKey &)documentKey {
  self.addedDocuments = [self.addedDocuments setByAddingObject:documentKey];
  self.removedDocuments = [self.removedDocuments setByRemovingObject:documentKey];
}

- (void)removeDocumentKey:(const DocumentKey &)documentKey {
  self.addedDocuments = [self.addedDocuments setByRemovingObject:documentKey];
  self.removedDocuments = [self.removedDocuments setByAddingObject:documentKey];
}

@end

#pragma mark - FSTTargetChange

@interface FSTTargetChange ()
@property(nonatomic, assign) FSTCurrentStatusUpdate currentStatusUpdate;
@property(nonatomic, strong, nullable) FSTTargetMapping *mapping;
@property(nonatomic, strong) FSTSnapshotVersion *snapshotVersion;
@property(nonatomic, strong) NSData *resumeToken;
@end

@implementation FSTTargetChange

- (instancetype)init {
  if (self = [super init]) {
    _currentStatusUpdate = FSTCurrentStatusUpdateNone;
    _resumeToken = [NSData data];
  }
  return self;
}

+ (instancetype)changeWithDocuments:(NSArray<FSTMaybeDocument *> *)docs
                currentStatusUpdate:(FSTCurrentStatusUpdate)currentStatusUpdate {
  FSTUpdateMapping *mapping = [[FSTUpdateMapping alloc] init];
  for (FSTMaybeDocument *doc in docs) {
    if ([doc isKindOfClass:[FSTDeletedDocument class]]) {
      mapping.removedDocuments = [mapping.removedDocuments setByAddingObject:doc.key];
    } else {
      mapping.addedDocuments = [mapping.addedDocuments setByAddingObject:doc.key];
    }
  }
  FSTTargetChange *change = [[FSTTargetChange alloc] init];
  change.mapping = mapping;
  change.currentStatusUpdate = currentStatusUpdate;
  return change;
}

+ (instancetype)changeWithMapping:(FSTTargetMapping *)mapping
                  snapshotVersion:(FSTSnapshotVersion *)snapshotVersion
              currentStatusUpdate:(FSTCurrentStatusUpdate)currentStatusUpdate {
  FSTTargetChange *change = [[FSTTargetChange alloc] init];
  change.mapping = mapping;
  change.snapshotVersion = snapshotVersion;
  change.currentStatusUpdate = currentStatusUpdate;
  return change;
}

- (FSTTargetMapping *)mapping {
  if (!_mapping) {
    // Create an FSTUpdateMapping by default, since resets are always explicit
    _mapping = [[FSTUpdateMapping alloc] init];
  }
  return _mapping;
}

/**
 * Sets the resume token but only when it has a new value. Empty resumeTokens are
 * discarded.
 */
- (void)setResumeToken:(NSData *)resumeToken {
  if (resumeToken.length > 0) {
    _resumeToken = resumeToken;
  }
}

@end

#pragma mark - FSTRemoteEvent

@interface FSTRemoteEvent () {
  NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *_targetChanges;
}

- (instancetype)
initWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
          targetChanges:(NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *)targetChanges
        documentUpdates:(std::map<DocumentKey, FSTMaybeDocument *>)documentUpdates;

@property(nonatomic, strong) FSTSnapshotVersion *snapshotVersion;

@end

@implementation FSTRemoteEvent {
  std::map<DocumentKey, FSTMaybeDocument *> _documentUpdates;
}
+ (instancetype)
eventWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
           targetChanges:(NSMutableDictionary<NSNumber *, FSTTargetChange *> *)targetChanges
         documentUpdates:(std::map<DocumentKey, FSTMaybeDocument *>)documentUpdates {
  return [[FSTRemoteEvent alloc] initWithSnapshotVersion:snapshotVersion
                                           targetChanges:targetChanges
                                         documentUpdates:std::move(documentUpdates)];
}

- (instancetype)initWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                          targetChanges:
                              (NSMutableDictionary<NSNumber *, FSTTargetChange *> *)targetChanges
                        documentUpdates:(std::map<DocumentKey, FSTMaybeDocument *>)documentUpdates {
  self = [super init];
  if (self) {
    _snapshotVersion = snapshotVersion;
    _targetChanges = targetChanges;
    _documentUpdates = std::move(documentUpdates);
  }
  return self;
}

- (void)filterUpdatesFromTargetChange:(FSTTargetChange *)targetChange
                    existingDocuments:(FSTDocumentKeySet *)existingDocuments {
  if ([targetChange.mapping isKindOfClass:[FSTUpdateMapping class]]) {
    FSTUpdateMapping *update = (FSTUpdateMapping *)targetChange.mapping;
    FSTDocumentKeySet *added = update.addedDocuments;
    __block FSTDocumentKeySet *result = added;
    [added enumerateObjectsUsingBlock:^(FSTDocumentKey *docKey, BOOL *stop) {
      if ([existingDocuments containsObject:docKey]) {
        result = [result setByRemovingObject:docKey];
      }
    }];
    update.addedDocuments = result;
  }
}

- (void)synthesizeDeleteForLimboTargetChange:(FSTTargetChange *)targetChange
                                         key:(const DocumentKey &)key {
  if (targetChange.currentStatusUpdate == FSTCurrentStatusUpdateMarkCurrent &&
      _documentUpdates.find(key) == _documentUpdates.end()) {
    // When listening to a query the server responds with a snapshot containing documents
    // matching the query and a current marker telling us we're now in sync. It's possible for
    // these to arrive as separate remote events or as a single remote event. For a document
    // query, there will be no documents sent in the response if the document doesn't exist.
    //
    // If the snapshot arrives separately from the current marker, we handle it normally and
    // updateTrackedLimboDocumentsWithChanges:targetID: will resolve the limbo status of the
    // document, removing it from limboDocumentRefs. This works because clients only initiate
    // limbo resolution when a target is current and because all current targets are always at a
    // consistent snapshot.
    //
    // However, if the document doesn't exist and the current marker arrives, the document is
    // not present in the snapshot and our normal view handling would consider the document to
    // remain in limbo indefinitely because there are no updates to the document. To avoid this,
    // we specially handle this just this case here: synthesizing a delete.
    //
    // TODO(dimond): Ideally we would have an explicit lookup query instead resulting in an
    // explicit delete message and we could remove this special logic.
    _documentUpdates[key] = [FSTDeletedDocument documentWithKey:key version:_snapshotVersion];
  }
}

- (NSDictionary<FSTBoxedTargetID *, FSTTargetChange *> *)targetChanges {
  return static_cast<NSDictionary<FSTBoxedTargetID *, FSTTargetChange *> *>(_targetChanges);
}

- (const std::map<DocumentKey, FSTMaybeDocument *> &)documentUpdates {
  return _documentUpdates;
}

/** Adds a document update to this remote event */
- (void)addDocumentUpdate:(FSTMaybeDocument *)document {
  _documentUpdates[document.key] = document;
}

/** Handles an existence filter mismatch */
- (void)handleExistenceFilterMismatchForTargetID:(FSTBoxedTargetID *)targetID {
  // An existence filter mismatch will reset the query and we need to reset the mapping to contain
  // no documents and an empty resume token.
  //
  // Note:
  //   * The reset mapping is empty, specifically forcing the consumer of the change to
  //     forget all keys for this targetID;
  //   * The resume snapshot for this target must be reset
  //   * The target must be unacked because unwatching and rewatching introduces a race for
  //     changes.
  //
  // TODO(dimond): keep track of reset targets not to raise.
  FSTTargetChange *targetChange =
      [FSTTargetChange changeWithMapping:[[FSTResetMapping alloc] init]
                         snapshotVersion:[FSTSnapshotVersion noVersion]
                     currentStatusUpdate:FSTCurrentStatusUpdateMarkNotCurrent];
  _targetChanges[targetID] = targetChange;
}

@end

#pragma mark - FSTWatchChangeAggregator

@interface FSTWatchChangeAggregator ()

/** The snapshot version for every target change this creates. */
@property(nonatomic, strong, readonly) FSTSnapshotVersion *snapshotVersion;

/** Keeps track of the current target mappings */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *targetChanges;

/** The set of open listens on the client */
@property(nonatomic, strong, readonly)
    NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *listenTargets;

/** Whether this aggregator was frozen and can no longer be modified */
@property(nonatomic, assign) BOOL frozen;

@end

@implementation FSTWatchChangeAggregator {
  NSMutableDictionary<FSTBoxedTargetID *, FSTExistenceFilter *> *_existenceFilters;
  /** Keeps track of document to update */
  std::map<DocumentKey, FSTMaybeDocument *> _documentUpdates;
}

- (instancetype)
initWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
          listenTargets:(NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)listenTargets
 pendingTargetResponses:(NSDictionary<FSTBoxedTargetID *, NSNumber *> *)pendingTargetResponses {
  self = [super init];
  if (self) {
    _snapshotVersion = snapshotVersion;

    _frozen = NO;
    _targetChanges = [NSMutableDictionary dictionary];
    _listenTargets = listenTargets;
    _pendingTargetResponses = [NSMutableDictionary dictionaryWithDictionary:pendingTargetResponses];

    _existenceFilters = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSDictionary<FSTBoxedTargetID *, FSTExistenceFilter *> *)existenceFilters {
  return static_cast<NSDictionary<FSTBoxedTargetID *, FSTExistenceFilter *> *>(_existenceFilters);
}

- (FSTTargetChange *)targetChangeForTargetID:(FSTBoxedTargetID *)targetID {
  FSTTargetChange *change = self.targetChanges[targetID];
  if (!change) {
    change = [[FSTTargetChange alloc] init];
    change.snapshotVersion = self.snapshotVersion;
    self.targetChanges[targetID] = change;
  }
  return change;
}

- (void)addWatchChanges:(NSArray<FSTWatchChange *> *)watchChanges {
  FSTAssert(!self.frozen, @"Trying to modify frozen FSTWatchChangeAggregator");
  for (FSTWatchChange *watchChange in watchChanges) {
    [self addWatchChange:watchChange];
  }
}

- (void)addWatchChange:(FSTWatchChange *)watchChange {
  FSTAssert(!self.frozen, @"Trying to modify frozen FSTWatchChangeAggregator");
  if ([watchChange isKindOfClass:[FSTDocumentWatchChange class]]) {
    [self addDocumentChange:(FSTDocumentWatchChange *)watchChange];
  } else if ([watchChange isKindOfClass:[FSTWatchTargetChange class]]) {
    [self addTargetChange:(FSTWatchTargetChange *)watchChange];
  } else if ([watchChange isKindOfClass:[FSTExistenceFilterWatchChange class]]) {
    [self addExistenceFilterChange:(FSTExistenceFilterWatchChange *)watchChange];
  } else {
    FSTFail(@"Unknown watch change: %@", watchChange);
  }
}

- (void)addDocumentChange:(FSTDocumentWatchChange *)docChange {
  BOOL relevant = NO;

  for (FSTBoxedTargetID *targetID in docChange.updatedTargetIDs) {
    if ([self isActiveTarget:targetID]) {
      FSTTargetChange *change = [self targetChangeForTargetID:targetID];
      [change.mapping addDocumentKey:docChange.documentKey];
      relevant = YES;
    }
  }

  for (FSTBoxedTargetID *targetID in docChange.removedTargetIDs) {
    if ([self isActiveTarget:targetID]) {
      FSTTargetChange *change = [self targetChangeForTargetID:targetID];
      [change.mapping removeDocumentKey:docChange.documentKey];
      relevant = YES;
    }
  }

  // Only update the document if there is a new document to replace, this might be just a target
  // update instead.
  if (docChange.document && relevant) {
    _documentUpdates[docChange.documentKey] = docChange.document;
  }
}

- (void)addTargetChange:(FSTWatchTargetChange *)targetChange {
  for (FSTBoxedTargetID *targetID in targetChange.targetIDs) {
    FSTTargetChange *change = [self targetChangeForTargetID:targetID];
    switch (targetChange.state) {
      case FSTWatchTargetChangeStateNoChange:
        if ([self isActiveTarget:targetID]) {
          // Creating the change above satisfies the semantics of no-change.
          change.resumeToken = targetChange.resumeToken;
        }
        break;
      case FSTWatchTargetChangeStateAdded:
        [self recordResponseForTargetID:targetID];
        if (![self.pendingTargetResponses objectForKey:targetID]) {
          // We have a freshly added target, so we need to reset any state that we had previously
          // This can happen e.g. when remove and add back a target for existence filter
          // mismatches.
          change.mapping = nil;
          change.currentStatusUpdate = FSTCurrentStatusUpdateNone;
          [_existenceFilters removeObjectForKey:targetID];
        }
        change.resumeToken = targetChange.resumeToken;
        break;
      case FSTWatchTargetChangeStateRemoved:
        // We need to keep track of removed targets to we can post-filter and remove any target
        // changes.
        [self recordResponseForTargetID:targetID];
        FSTAssert(!targetChange.cause, @"WatchChangeAggregator does not handle errored targets.");
        break;
      case FSTWatchTargetChangeStateCurrent:
        if ([self isActiveTarget:targetID]) {
          change.currentStatusUpdate = FSTCurrentStatusUpdateMarkCurrent;
          change.resumeToken = targetChange.resumeToken;
        }
        break;
      case FSTWatchTargetChangeStateReset:
        if ([self isActiveTarget:targetID]) {
          // Overwrite any existing target mapping with a reset mapping. Every subsequent update
          // will modify the reset mapping, not an update mapping.
          change.mapping = [[FSTResetMapping alloc] init];
          change.resumeToken = targetChange.resumeToken;
        }
        break;
      default:
        FSTWarn(@"Unknown target watch change type: %ld", (long)targetChange.state);
    }
  }
}

/**
 * Records that we got a watch target add/remove by decrementing the number of pending target
 * responses that we have.
 */
- (void)recordResponseForTargetID:(FSTBoxedTargetID *)targetID {
  NSNumber *count = [self.pendingTargetResponses objectForKey:targetID];
  int newCount = count ? [count intValue] - 1 : -1;
  if (newCount == 0) {
    [self.pendingTargetResponses removeObjectForKey:targetID];
  } else {
    [self.pendingTargetResponses setObject:[NSNumber numberWithInt:newCount] forKey:targetID];
  }
}

/**
 * Returns true if the given targetId is active. Active targets are those for which there are no
 * pending requests to add a listen and are in the current list of targets the client cares about.
 *
 * Clients can repeatedly listen and stop listening to targets, so this check is useful in
 * preventing in preventing race conditions for a target where events arrive but the server hasn't
 * yet acknowledged the intended change in state.
 */
- (BOOL)isActiveTarget:(FSTBoxedTargetID *)targetID {
  return [self.listenTargets objectForKey:targetID] &&
         ![self.pendingTargetResponses objectForKey:targetID];
}

- (void)addExistenceFilterChange:(FSTExistenceFilterWatchChange *)existenceFilterChange {
  FSTBoxedTargetID *targetID = @(existenceFilterChange.targetID);
  if ([self isActiveTarget:targetID]) {
    _existenceFilters[targetID] = existenceFilterChange.filter;
  }
}

- (FSTRemoteEvent *)remoteEvent {
  NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *targetChanges = self.targetChanges;

  NSMutableArray *targetsToRemove = [NSMutableArray array];

  // Apply any inactive targets.
  for (FSTBoxedTargetID *targetID in [targetChanges keyEnumerator]) {
    if (![self isActiveTarget:targetID]) {
      [targetsToRemove addObject:targetID];
    }
  }

  [targetChanges removeObjectsForKeys:targetsToRemove];

  // Mark this aggregator as frozen so no further modifications are made.
  self.frozen = YES;
  return [FSTRemoteEvent eventWithSnapshotVersion:self.snapshotVersion
                                    targetChanges:targetChanges
                                  documentUpdates:_documentUpdates];
}

@end

NS_ASSUME_NONNULL_END
