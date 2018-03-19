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

#include <string>

#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTLogger.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTargetMapping

@interface FSTTargetMapping ()

/** Private mutator method to add a document key to the mapping */
- (void)addDocumentKey:(FSTDocumentKey *)documentKey;

/** Private mutator method to remove a document key from the mapping */
- (void)removeDocumentKey:(FSTDocumentKey *)documentKey;

@end

@implementation FSTTargetMapping

- (void)addDocumentKey:(FSTDocumentKey *)documentKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

- (void)removeDocumentKey:(FSTDocumentKey *)documentKey {
  @throw FSTAbstractMethodException();  // NOLINT
}

@end

#pragma mark - FSTResetMapping

@implementation FSTResetMapping {
  DocumentKeySet _documents;
}

+ (instancetype)mappingWithDocuments:(NSArray<FSTDocument *> *)documents {
  FSTResetMapping *mapping = [[FSTResetMapping alloc] init];
  for (FSTDocument *doc in documents) {
    mapping->_documents.insert(doc.key);
  }
  return mapping;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _documents = DocumentKeySet{};
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
  return _documents == otherMapping->_documents;
}

- (NSUInteger)hash {
  NSUInteger result = 0;
  for (const auto &doc : _documents) {
    result = result * 31u + std::hash<std::string>{}(doc.ToString());
  }
  return result;
}

- (void)addDocumentKey:(FSTDocumentKey *)documentKey {
  _documents.insert(documentKey);
}

- (void)removeDocumentKey:(FSTDocumentKey *)documentKey {
  _documents.erase(documentKey);
}

- (const DocumentKeySet &)documents {
  return _documents;
}

@end

#pragma mark - FSTUpdateMapping

@implementation FSTUpdateMapping {
  DocumentKeySet _addedDocuments;
  DocumentKeySet _removedDocuments;
}

+ (FSTUpdateMapping *)mappingWithAddedDocuments:(NSArray<FSTDocument *> *)added
                               removedDocuments:(NSArray<FSTDocument *> *)removed {
  FSTUpdateMapping *mapping = [[FSTUpdateMapping alloc] init];
  for (FSTDocument *doc in added) {
    mapping->_addedDocuments.insert(doc.key);
  }
  for (FSTDocument *doc in removed) {
    mapping->_removedDocuments.insert(doc.key);
  }
  return mapping;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _addedDocuments = DocumentKeySet{};
    _removedDocuments = DocumentKeySet{};
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
  return _addedDocuments == otherMapping->_addedDocuments &&
         _removedDocuments == otherMapping->_removedDocuments;
}

- (NSUInteger)hash {
  return DocumentKeySetHash(*self.addedDocuments) * 31 + DocumentKeySetHash(*self.removedDocuments);
}

- (void)applyTo:(DocumentKeySet *)keys {
  for (const auto &key : _addedDocuments) {
    keys->insert(key);
  };
  for (const auto &key : _removedDocuments) {
    keys->erase(key);
  };
}

- (void)addDocumentKey:(FSTDocumentKey *)documentKey {
  _addedDocuments.insert(documentKey);
  _removedDocuments.erase(documentKey);
}

- (void)removeDocumentKey:(FSTDocumentKey *)documentKey {
  _addedDocuments.erase(documentKey);
  _removedDocuments.insert(documentKey);
}

- (DocumentKeySet *)addedDocuments {
  return &_addedDocuments;
}

- (DocumentKeySet *)removedDocuments {
  return &_removedDocuments;
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
      mapping.removedDocuments->insert(doc.key);
    } else {
      mapping.addedDocuments->insert(doc.key);
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
  NSMutableDictionary<FSTDocumentKey *, FSTMaybeDocument *> *_documentUpdates;
  NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *_targetChanges;
}

- (instancetype)
initWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
          targetChanges:(NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *)targetChanges
        documentUpdates:
            (NSMutableDictionary<FSTDocumentKey *, FSTMaybeDocument *> *)documentUpdates;

@property(nonatomic, strong) FSTSnapshotVersion *snapshotVersion;

@end

@implementation FSTRemoteEvent

+ (instancetype)
eventWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
           targetChanges:(NSMutableDictionary<NSNumber *, FSTTargetChange *> *)targetChanges
         documentUpdates:
             (NSMutableDictionary<FSTDocumentKey *, FSTMaybeDocument *> *)documentUpdates {
  return [[FSTRemoteEvent alloc] initWithSnapshotVersion:snapshotVersion
                                           targetChanges:targetChanges
                                         documentUpdates:documentUpdates];
}

- (instancetype)
initWithSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
          targetChanges:(NSMutableDictionary<NSNumber *, FSTTargetChange *> *)targetChanges
        documentUpdates:
            (NSMutableDictionary<FSTDocumentKey *, FSTMaybeDocument *> *)documentUpdates {
  self = [super init];
  if (self) {
    _snapshotVersion = snapshotVersion;
    _targetChanges = targetChanges;
    _documentUpdates = documentUpdates;
  }
  return self;
}

- (NSDictionary<FSTBoxedTargetID *, FSTTargetChange *> *)targetChanges {
  return static_cast<NSDictionary<FSTBoxedTargetID *, FSTTargetChange *> *>(_targetChanges);
}

- (NSDictionary<FSTDocumentKey *, FSTMaybeDocument *> *)documentUpdates {
  return static_cast<NSDictionary<FSTDocumentKey *, FSTMaybeDocument *> *>(_documentUpdates);
}

/** Adds a document update to this remote event */
- (void)addDocumentUpdate:(FSTMaybeDocument *)document {
  _documentUpdates[(FSTDocumentKey *)document.key] = document;
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

/** Keeps track of document to update */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTDocumentKey *, FSTMaybeDocument *> *documentUpdates;

/** The set of open listens on the client */
@property(nonatomic, strong, readonly)
    NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *listenTargets;

/** Whether this aggregator was frozen and can no longer be modified */
@property(nonatomic, assign) BOOL frozen;

@end

@implementation FSTWatchChangeAggregator {
  NSMutableDictionary<FSTBoxedTargetID *, FSTExistenceFilter *> *_existenceFilters;
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
    _documentUpdates = [NSMutableDictionary dictionary];
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
    self.documentUpdates[docChange.documentKey] = docChange.document;
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
                                  documentUpdates:self.documentUpdates];
}

@end

NS_ASSUME_NONNULL_END
