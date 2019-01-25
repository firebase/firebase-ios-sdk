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
#include <set>
#include <utility>
#include <vector>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::firestore::core::DocumentViewChangeType;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;
using firebase::firestore::util::Hash;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTRemoteEvent {
  SnapshotVersion _snapshotVersion;
  std::unordered_map<TargetId, TargetChange> _targetChanges;
  std::unordered_set<TargetId> _targetMismatches;
  std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash> _documentUpdates;
  DocumentKeySet _limboDocumentChanges;
}

- (instancetype)
    initWithSnapshotVersion:(SnapshotVersion)snapshotVersion
              targetChanges:(std::unordered_map<TargetId, TargetChange>)targetChanges
           targetMismatches:(std::unordered_set<TargetId>)targetMismatches
            documentUpdates:(std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash>)
                                documentUpdates
             limboDocuments:(DocumentKeySet)limboDocuments {
  self = [super init];
  if (self) {
    _snapshotVersion = std::move(snapshotVersion);
    _targetChanges = std::move(targetChanges);
    _targetMismatches = std::move(targetMismatches);
    _documentUpdates = std::move(documentUpdates);
    _limboDocumentChanges = std::move(limboDocuments);
  }
  return self;
}

- (const SnapshotVersion &)snapshotVersion {
  return _snapshotVersion;
}

- (const DocumentKeySet &)limboDocumentChanges {
  return _limboDocumentChanges;
}

- (const std::unordered_map<TargetId, TargetChange> &)targetChanges {
  return _targetChanges;
}

- (const std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash> &)documentUpdates {
  return _documentUpdates;
}

- (const std::unordered_set<TargetId> &)targetMismatches {
  return _targetMismatches;
}

@end

NS_ASSUME_NONNULL_END
