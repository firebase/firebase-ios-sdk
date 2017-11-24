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

#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalViewChanges ()
- (instancetype)initWithQuery:(FSTQuery *)query
                    addedKeys:(FSTDocumentKeySet *)addedKeys
                  removedKeys:(FSTDocumentKeySet *)removedKeys NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTLocalViewChanges

+ (instancetype)changesForViewSnapshot:(FSTViewSnapshot *)viewSnapshot {
  FSTDocumentKeySet *addedKeys = [FSTDocumentKeySet keySet];
  FSTDocumentKeySet *removedKeys = [FSTDocumentKeySet keySet];

  for (FSTDocumentViewChange *docChange in viewSnapshot.documentChanges) {
    switch (docChange.type) {
      case FSTDocumentViewChangeTypeAdded:
        addedKeys = [addedKeys setByAddingObject:docChange.document.key];
        break;

      case FSTDocumentViewChangeTypeRemoved:
        removedKeys = [removedKeys setByAddingObject:docChange.document.key];
        break;

      default:
        // Do nothing.
        break;
    }
  }

  return [self changesForQuery:viewSnapshot.query addedKeys:addedKeys removedKeys:removedKeys];
}

+ (instancetype)changesForQuery:(FSTQuery *)query
                      addedKeys:(FSTDocumentKeySet *)addedKeys
                    removedKeys:(FSTDocumentKeySet *)removedKeys {
  return
      [[FSTLocalViewChanges alloc] initWithQuery:query addedKeys:addedKeys removedKeys:removedKeys];
}

- (instancetype)initWithQuery:(FSTQuery *)query
                    addedKeys:(FSTDocumentKeySet *)addedKeys
                  removedKeys:(FSTDocumentKeySet *)removedKeys {
  self = [super init];
  if (self) {
    _query = query;
    _addedKeys = addedKeys;
    _removedKeys = removedKeys;
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
