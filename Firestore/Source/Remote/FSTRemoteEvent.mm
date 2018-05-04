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

#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTLogger.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::util::Hash;
using firebase::firestore::model::DocumentKeySet;

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

- (void)filterUpdatesUsingExistingKeys:(const DocumentKeySet &)existingKeys {
  @throw FSTAbstractMethodException();  // NOLINT
}

@end

#pragma mark - FSTResetMapping

@implementation FSTResetMapping {
  DocumentKeySet _documents;
}

+ (instancetype)mappingWithDocuments:(NSArray<FSTDocument *> *)documents {
  DocumentKeySet keys;
  for (FSTDocument *doc in documents) {
    keys = keys.insert(doc.key);
  }
  return [[FSTResetMapping alloc] initWithDocuments:std::move(keys)];
}

- (instancetype)initWithDocuments:(DocumentKeySet)documents {
  self = [super init];
  if (self) {
    _documents = std::move(documents);
  }
  return self;
}

- (const DocumentKeySet &)documents {
  return _documents;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTResetMapping class]]) {
    return NO;
  }

  FSTResetMapping *otherMapping = (FSTResetMapping *)other;
  return _documents == otherMapping.documents;
}

- (NSUInteger)hash {
  return Hash(_documents);
}

- (void)addDocumentKey:(const DocumentKey &)documentKey {
  _documents = _documents.insert(documentKey);
}

- (void)removeDocumentKey:(const DocumentKey &)documentKey {
  _documents = _documents.erase(documentKey);
}

- (void)filterUpdatesUsingExistingKeys:(const DocumentKeySet &)existingKeys {
  // No-op. Resets are not filtered.
}

@end

#pragma mark - FSTUpdateMapping

@implementation FSTUpdateMapping {
  DocumentKeySet _addedDocuments;
  DocumentKeySet _removedDocuments;
}

+ (FSTUpdateMapping *)mappingWithAddedDocuments:(NSArray<FSTDocument *> *)added
                               removedDocuments:(NSArray<FSTDocument *> *)removed {
  DocumentKeySet addedDocuments;
  DocumentKeySet removedDocuments;
  for (FSTDocument *doc in added) {
    addedDocuments = addedDocuments.insert(doc.key);
  }
  for (FSTDocument *doc in removed) {
    removedDocuments = removedDocuments.insert(doc.key);
  }
  return [[FSTUpdateMapping alloc] initWithAddedDocuments:std::move(addedDocuments)
                                         removedDocuments:std::move(removedDocuments)];
}

- (instancetype)initWithAddedDocuments:(DocumentKeySet)addedDocuments
                      removedDocuments:(DocumentKeySet)removedDocuments {
  self = [super init];
  if (self) {
    _addedDocuments = std::move(addedDocuments);
    _removedDocuments = std::move(removedDocuments);
  }
  return self;
}

- (const DocumentKeySet &)addedDocuments {
  return _addedDocuments;
}

- (const DocumentKeySet &)removedDocuments {
  return _removedDocuments;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTUpdateMapping class]]) {
    return NO;
  }

  FSTUpdateMapping *otherMapping = (FSTUpdateMapping *)other;
  return _addedDocuments == otherMapping.addedDocuments &&
         _removedDocuments == otherMapping.removedDocuments;
}

- (NSUInteger)hash {
  return Hash(_addedDocuments, _removedDocuments);
}

- (DocumentKeySet)applyTo:(const DocumentKeySet &)keys {
  DocumentKeySet result = keys;
  for (const DocumentKey &key : _addedDocuments) {
    result = result.insert(key);
  }
  for (const DocumentKey &key : _removedDocuments) {
    result = result.erase(key);
  }
  return result;
}

- (void)addDocumentKey:(const DocumentKey &)documentKey {
  _addedDocuments = _addedDocuments.insert(documentKey);
  _removedDocuments = _removedDocuments.erase(documentKey);
}

- (void)removeDocumentKey:(const DocumentKey &)documentKey {
  _addedDocuments = _addedDocuments.erase(documentKey);
  _removedDocuments = _removedDocuments.insert(documentKey);
}

- (void)filterUpdatesUsingExistingKeys:(const DocumentKeySet &)existingKeys {
  DocumentKeySet result = _addedDocuments;
  for (const DocumentKey &key : _addedDocuments) {
    if (existingKeys.contains(key)) {
      result = result.erase(key);
    }
  }
  _addedDocuments = result;
}

@end

#pragma mark - FSTTargetChange

@interface FSTTargetChange ()
@property(nonatomic, assign) FSTCurrentStatusUpdate currentStatusUpdate;
@property(nonatomic, strong, nullable) FSTTargetMapping *mapping;
@property(nonatomic, strong) NSData *resumeToken;
@end

@implementation FSTTargetChange {
  SnapshotVersion _snapshotVersion;
}

- (instancetype)init {
  if (self = [super init]) {
    _currentStatusUpdate = FSTCurrentStatusUpdateNone;
    _resumeToken = [NSData data];
  }
  return self;
}

- (instancetype)initWithSnapshotVersion:(SnapshotVersion)snapshotVersion {
  if (self = [self init]) {
    _snapshotVersion = std::move(snapshotVersion);
  }
  return self;
}

- (const SnapshotVersion &)snapshotVersion {
  return _snapshotVersion;
}

+ (instancetype)changeWithDocuments:(NSArray<FSTMaybeDocument *> *)docs
                currentStatusUpdate:(FSTCurrentStatusUpdate)currentStatusUpdate {
  DocumentKeySet addedDocuments;
  DocumentKeySet removedDocuments;
  for (FSTMaybeDocument *doc in docs) {
    if ([doc isKindOfClass:[FSTDeletedDocument class]]) {
      removedDocuments = removedDocuments.insert(doc.key);
    } else {
      addedDocuments = addedDocuments.insert(doc.key);
    }
  }
  FSTUpdateMapping *mapping =
      [[FSTUpdateMapping alloc] initWithAddedDocuments:std::move(addedDocuments)
                                      removedDocuments:std::move(removedDocuments)];

  FSTTargetChange *change = [[FSTTargetChange alloc] init];
  change.mapping = mapping;
  change.currentStatusUpdate = currentStatusUpdate;
  return change;
}

+ (instancetype)changeWithMapping:(FSTTargetMapping *)mapping
                  snapshotVersion:(SnapshotVersion)snapshotVersion
              currentStatusUpdate:(FSTCurrentStatusUpdate)currentStatusUpdate {
  FSTTargetChange *change = [[FSTTargetChange alloc] init];
  change.mapping = mapping;
  change->_snapshotVersion = std::move(snapshotVersion);
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

@implementation FSTRemoteEvent {
  SnapshotVersion _snapshotVersion;
  NSMutableDictionary<FSTBoxedTargetID *, FSTTargetChange *> *_targetChanges;
  std::map<DocumentKey, FSTMaybeDocument *> _documentUpdates;
  DocumentKeySet _limboDocumentChanges;
}

- (instancetype)initWithSnapshotVersion:(SnapshotVersion)snapshotVersion
                          targetChanges:
                              (NSMutableDictionary<NSNumber *, FSTTargetChange *> *)targetChanges
                        documentUpdates:(std::map<DocumentKey, FSTMaybeDocument *>)documentUpdates
                         limboDocuments:(DocumentKeySet)limboDocuments {
  self = [super init];
  if (self) {
    _snapshotVersion = std::move(snapshotVersion);
    _targetChanges = targetChanges;
    _documentUpdates = std::move(documentUpdates);
    _limboDocumentChanges = std::move(limboDocuments);
  }
  return self;
}

- (NSDictionary<FSTBoxedTargetID *, FSTTargetChange *> *)targetChanges {
  return _targetChanges;
}

- (const DocumentKeySet &)limboDocumentChanges {
  return _limboDocumentChanges;
}

- (const std::map<DocumentKey, FSTMaybeDocument *> &)documentUpdates {
  return _documentUpdates;
}

- (const SnapshotVersion &)snapshotVersion {
  return _snapshotVersion;
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
    // we specially handle this case here: synthesizing a delete.
    //
    // TODO(dimond): Ideally we would have an explicit lookup query instead resulting in an
    // explicit delete message and we could remove this special logic.
    _documentUpdates[key] = [FSTDeletedDocument documentWithKey:key version:_snapshotVersion];
    _limboDocumentChanges = _limboDocumentChanges.insert(key);
  }
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
                         snapshotVersion:SnapshotVersion::None()
                     currentStatusUpdate:FSTCurrentStatusUpdateMarkNotCurrent];
  _targetChanges[targetID] = targetChange;
}

@end

#pragma mark - FSTWatchChangeAggregator

@interface FSTWatchChangeAggregator ()

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

  DocumentKeySet _limboDocuments;
  /** The snapshot version for every target change this creates. */
  SnapshotVersion _snapshotVersion;
}

- (instancetype)
initWithSnapshotVersion:(SnapshotVersion)snapshotVersion
          listenTargets:(NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)listenTargets
 pendingTargetResponses:(NSDictionary<FSTBoxedTargetID *, NSNumber *> *)pendingTargetResponses {
  self = [super init];
  if (self) {
    _snapshotVersion = std::move(snapshotVersion);

    _frozen = NO;
    _targetChanges = [NSMutableDictionary dictionary];
    _listenTargets = listenTargets;
    _pendingTargetResponses = [NSMutableDictionary dictionaryWithDictionary:pendingTargetResponses];
    _limboDocuments = DocumentKeySet{};
    _existenceFilters = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSDictionary<FSTBoxedTargetID *, FSTExistenceFilter *> *)existenceFilters {
  return _existenceFilters;
}

- (FSTTargetChange *)targetChangeForTargetID:(FSTBoxedTargetID *)targetID {
  FSTTargetChange *change = self.targetChanges[targetID];
  if (!change) {
    change = [[FSTTargetChange alloc] initWithSnapshotVersion:_snapshotVersion];
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

/**
 * Updates limbo document tracking for a given target-document mapping change. If the target is a
 * limbo target, and the change for the document has only seen limbo targets so far, and we are not
 * already tracking a change for this document, then consider this document a limbo document update.
 * Otherwise, ensure that we don't consider this document a limbo document. Returns true if the
 * change still has only seen limbo resolution changes.
 */
- (BOOL)updateLimboDocumentsForKey:(const DocumentKey &)documentKey
                         queryData:(FSTQueryData *)queryData
                       isOnlyLimbo:(BOOL)isOnlyLimbo {
  if (!isOnlyLimbo) {
    // It wasn't a limbo doc before, so it definitely isn't now.
    return NO;
  }
  if (_documentUpdates.find(documentKey) == _documentUpdates.end()) {
    // We haven't seen a document update for this key yet.
    if (queryData.purpose == FSTQueryPurposeLimboResolution) {
      // We haven't seen this document before, and this target is a limbo target.
      _limboDocuments = _limboDocuments.insert(documentKey);
      return YES;
    } else {
      // We haven't seen the document before, but this is a non-limbo target.
      // Since we haven't seen it, we know it's not in our set of limbo docs. Return NO to ensure
      // that this key is marked as non-limbo.
      return NO;
    }
  } else if (queryData.purpose == FSTQueryPurposeLimboResolution) {
    // We have only seen limbo targets so far for this document, and this is another limbo target.
    return YES;
  } else {
    // We haven't marked this as non-limbo yet, but this target is not a limbo target.
    // Mark the key as non-limbo and make sure it isn't in our set.
    _limboDocuments = _limboDocuments.erase(documentKey);
    return NO;
  }
}

- (void)addDocumentChange:(FSTDocumentWatchChange *)docChange {
  BOOL relevant = NO;
  BOOL isOnlyLimbo = YES;

  for (FSTBoxedTargetID *targetID in docChange.updatedTargetIDs) {
    FSTQueryData *queryData = [self queryDataForActiveTarget:targetID];
    if (queryData) {
      FSTTargetChange *change = [self targetChangeForTargetID:targetID];
      isOnlyLimbo = [self updateLimboDocumentsForKey:docChange.documentKey
                                           queryData:queryData
                                         isOnlyLimbo:isOnlyLimbo];
      [change.mapping addDocumentKey:docChange.documentKey];
      relevant = YES;
    }
  }

  for (FSTBoxedTargetID *targetID in docChange.removedTargetIDs) {
    FSTQueryData *queryData = [self queryDataForActiveTarget:targetID];
    if (queryData) {
      FSTTargetChange *change = [self targetChangeForTargetID:targetID];
      isOnlyLimbo = [self updateLimboDocumentsForKey:docChange.documentKey
                                           queryData:queryData
                                         isOnlyLimbo:isOnlyLimbo];
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
        if (!self.pendingTargetResponses[targetID]) {
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
  NSNumber *count = self.pendingTargetResponses[targetID];
  int newCount = count ? [count intValue] - 1 : -1;
  if (newCount == 0) {
    [self.pendingTargetResponses removeObjectForKey:targetID];
  } else {
    self.pendingTargetResponses[targetID] = @(newCount);
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
  return [self queryDataForActiveTarget:targetID] != nil;
}

- (FSTQueryData *_Nullable)queryDataForActiveTarget:(FSTBoxedTargetID *)targetID {
  FSTQueryData *queryData = self.listenTargets[targetID];
  return (queryData && !self.pendingTargetResponses[targetID]) ? queryData : nil;
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
  return [[FSTRemoteEvent alloc] initWithSnapshotVersion:_snapshotVersion
                                           targetChanges:targetChanges
                                         documentUpdates:_documentUpdates
                                          limboDocuments:_limboDocuments];
}

@end

NS_ASSUME_NONNULL_END
