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

#import "Firestore/Source/Model/FSTDocumentKey.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMultiReferenceSet

@interface FSTEagerGarbageCollector ()

/** The garbage collectible sources to double-check during garbage collection. */
@property(nonatomic, strong, readonly) NSMutableArray<id<FSTGarbageSource>> *sources;

/** A set of potentially garbage keys. */
@property(nonatomic, strong, readonly) NSMutableSet<FSTDocumentKey *> *potentialGarbage;

@end

@implementation FSTEagerGarbageCollector

- (instancetype)init {
  self = [super init];
  if (self) {
    _sources = [NSMutableArray array];
    _potentialGarbage = [[NSMutableSet alloc] init];
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

- (void)addPotentialGarbageKey:(FSTDocumentKey *)key {
  [self.potentialGarbage addObject:key];
}

- (NSMutableSet<FSTDocumentKey *> *)collectGarbage {
  NSMutableArray<id<FSTGarbageSource>> *sources = self.sources;

  NSMutableSet<FSTDocumentKey *> *actualGarbage = [NSMutableSet set];
  for (FSTDocumentKey *key in self.potentialGarbage) {
    BOOL isGarbage = YES;
    for (id<FSTGarbageSource> source in sources) {
      if ([source containsKey:key]) {
        isGarbage = NO;
        break;
      }
    }

    if (isGarbage) {
      [actualGarbage addObject:key];
    }
  }

  // Clear locally retained potential keys and returned confirmed garbage.
  [self.potentialGarbage removeAllObjects];
  return actualGarbage;
}

@end

NS_ASSUME_NONNULL_END
