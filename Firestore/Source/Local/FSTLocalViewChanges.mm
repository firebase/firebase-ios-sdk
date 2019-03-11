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

#import "Firestore/Source/Local/FSTLocalViewChanges.h"

#include <utility>

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"

using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalViewChanges ()
- (instancetype)initWithTarget:(TargetId)targetID
                     addedKeys:(DocumentKeySet)addedKeys
                   removedKeys:(DocumentKeySet)removedKeys NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTLocalViewChanges {
  DocumentKeySet _addedKeys;
  DocumentKeySet _removedKeys;
}

+ (instancetype)changesForViewSnapshot:(const ViewSnapshot &)viewSnapshot
                          withTargetID:(TargetId)targetID {
  DocumentKeySet addedKeys;
  DocumentKeySet removedKeys;

  for (const DocumentViewChange &docChange : viewSnapshot.document_changes()) {
    switch (docChange.type()) {
      case DocumentViewChange::Type::kAdded:
        addedKeys = addedKeys.insert(docChange.document().key);
        break;

      case DocumentViewChange::Type::kRemoved:
        removedKeys = removedKeys.insert(docChange.document().key);
        break;

      default:
        // Do nothing.
        break;
    }
  }

  return [self changesForTarget:targetID
                      addedKeys:std::move(addedKeys)
                    removedKeys:std::move(removedKeys)];
}

+ (instancetype)changesForTarget:(TargetId)targetID
                       addedKeys:(DocumentKeySet)addedKeys
                     removedKeys:(DocumentKeySet)removedKeys {
  return [[FSTLocalViewChanges alloc] initWithTarget:targetID
                                           addedKeys:std::move(addedKeys)
                                         removedKeys:std::move(removedKeys)];
}

- (instancetype)initWithTarget:(TargetId)targetID
                     addedKeys:(DocumentKeySet)addedKeys
                   removedKeys:(DocumentKeySet)removedKeys {
  self = [super init];
  if (self) {
    _targetID = targetID;
    _addedKeys = std::move(addedKeys);
    _removedKeys = std::move(removedKeys);
  }
  return self;
}

- (const DocumentKeySet &)addedKeys {
  return _addedKeys;
}

- (const DocumentKeySet &)removedKeys {
  return _removedKeys;
}

@end

NS_ASSUME_NONNULL_END
