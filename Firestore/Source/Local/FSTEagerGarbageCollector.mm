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

#import "Firestore/Source/Local/FSTEagerGarbageCollector.h"

#include <set>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMultiReferenceSet

@interface FSTEagerGarbageCollector ()

/** The garbage collectible sources to double-check during garbage collection. */
@property(nonatomic, strong, readonly) NSMutableArray<id<FSTGarbageSource>> *sources;

@end

@implementation FSTEagerGarbageCollector {
  /** A set of potentially garbage keys. */
  std::set<DocumentKey> _potentialGarbage;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _sources = [NSMutableArray array];
  }
  return self;
}

- (BOOL)isEager {
  return YES;
}

- (void)addGarbageSource:(id<FSTGarbageSource>)garbageSource {
  [self.sources addObject:garbageSource];
  garbageSource.garbageCollector = self;
}

- (void)removeGarbageSource:(id<FSTGarbageSource>)garbageSource {
  [self.sources removeObject:garbageSource];
  garbageSource.garbageCollector = nil;
}

- (void)addPotentialGarbageKey:(const DocumentKey &)key {
  _potentialGarbage.insert(key);
}

- (std::set<DocumentKey>)collectGarbage {
  NSMutableArray<id<FSTGarbageSource>> *sources = self.sources;

  std::set<DocumentKey> actualGarbage;
  for (const DocumentKey &key : _potentialGarbage) {
    BOOL isGarbage = YES;
    for (id<FSTGarbageSource> source in sources) {
      if ([source containsKey:key]) {
        isGarbage = NO;
        break;
      }
    }

    if (isGarbage) {
      actualGarbage.insert(key);
    }
  }

  // Clear locally retained potential keys and returned confirmed garbage.
  _potentialGarbage.clear();
  return actualGarbage;
}

@end

NS_ASSUME_NONNULL_END
