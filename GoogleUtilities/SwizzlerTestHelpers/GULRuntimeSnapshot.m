// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GULRuntimeSnapshot.h"

#import <objc/runtime.h>

#import "GULRuntimeClassDiff.h"
#import "GULRuntimeClassSnapshot.h"
#import "GULRuntimeDiff.h"

@implementation GULRuntimeSnapshot {
  /** The set of tracked classes. */
  NSSet<Class> *__nullable _classes;

  /** The class snapshots for each tracked class. */
  NSMutableDictionary<NSString *, GULRuntimeClassSnapshot *> *_classSnapshots;

  /** The hash value of this object. */
  NSUInteger _runningHash;
}

- (instancetype)init {
  return [self initWithClasses:nil];
}

- (instancetype)initWithClasses:(nullable NSSet<Class> *)classes {
  self = [super init];
  if (self) {
    _classSnapshots = [[NSMutableDictionary alloc] init];
    _classes = classes;
    _runningHash = [_classes hash] ^ [_classSnapshots hash];
  }
  return self;
}

- (NSUInteger)hash {
  return _runningHash;
}

- (BOOL)isEqual:(id)object {
  return [self hash] == [object hash];
}

- (NSString *)description {
  return [[super description] stringByAppendingFormat:@" Hash: 0x%lX", (unsigned long)[self hash]];
}

- (void)capture {
  int numberOfClasses = objc_getClassList(NULL, 0);
  Class *classList = (Class *)malloc(numberOfClasses * sizeof(Class));
  numberOfClasses = objc_getClassList(classList, numberOfClasses);

  // If we should track specific classes, then there's no need to figure out all ObjC classes.
  if (_classes) {
    for (Class aClass in _classes) {
      NSString *classString = NSStringFromClass(aClass);
      GULRuntimeClassSnapshot *classSnapshot =
          [[GULRuntimeClassSnapshot alloc] initWithClass:aClass];
      _classSnapshots[classString] = classSnapshot;
      [classSnapshot capture];
      _runningHash ^= [classSnapshot hash];
    }
  } else {
    for (int i = 0; i < numberOfClasses; i++) {
      Class aClass = classList[i];
      NSString *classString = NSStringFromClass(aClass);
      GULRuntimeClassSnapshot *classSnapshot =
          [[GULRuntimeClassSnapshot alloc] initWithClass:aClass];
      _classSnapshots[classString] = classSnapshot;
      [classSnapshot capture];
      _runningHash ^= [classSnapshot hash];
    }
  }
  free(classList);
}

- (GULRuntimeDiff *)diff:(GULRuntimeSnapshot *)otherSnapshot {
  GULRuntimeDiff *runtimeDiff = [[GULRuntimeDiff alloc] init];
  NSSet *setOne = [NSSet setWithArray:[_classSnapshots allKeys]];
  NSSet *setTwo = [NSSet setWithArray:[otherSnapshot->_classSnapshots allKeys]];

  // All items contained within setOne, but not in setTwo.
  NSSet *removedClasses = [setOne
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 id _Nullable evaluatedObject,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return ![setTwo containsObject:evaluatedObject];
      }]];

  // All items contained within setTwo, but not in setOne.
  NSSet *addedClasses = [setTwo
      filteredSetUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(
                                                 id _Nullable evaluatedObject,
                                                 NSDictionary<NSString *, id> *_Nullable bindings) {
        return ![setOne containsObject:evaluatedObject];
      }]];
  runtimeDiff.removedClasses = removedClasses;
  runtimeDiff.addedClasses = addedClasses;

  NSMutableSet<GULRuntimeClassDiff *> *classDiffs = [[NSMutableSet alloc] init];
  [_classSnapshots
      enumerateKeysAndObjectsUsingBlock:^(
          NSString *_Nonnull key, GULRuntimeClassSnapshot *_Nonnull obj, BOOL *_Nonnull stop) {
        GULRuntimeClassSnapshot *classSnapshot = self->_classSnapshots[key];
        GULRuntimeClassSnapshot *otherClassSnapshot = otherSnapshot->_classSnapshots[key];
        GULRuntimeClassDiff *classDiff = [classSnapshot diff:otherClassSnapshot];
        if ([classDiff hash]) {
          NSAssert(![classDiffs containsObject:classDiff],
                   @"An equivalent class diff has already been stored.");
          [classDiffs addObject:classDiff];
        }
      }];
  runtimeDiff.classDiffs = classDiffs;
  return runtimeDiff;
}

@end
