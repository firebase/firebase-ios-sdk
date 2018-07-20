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

#import "GULRuntimeStateHelper.h"

#import <objc/runtime.h>

#import "GULRuntimeSnapshot.h"

@implementation GULRuntimeStateHelper

/** Initializes and returns the snapshot cache.
 *
 *  @return A singleton snapshot cache.
 */
+ (NSMutableArray<GULRuntimeSnapshot *> *)snapshotCache {
  static NSMutableArray<GULRuntimeSnapshot *> *snapshots;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    snapshots = [[NSMutableArray<GULRuntimeSnapshot *> alloc] init];
  });
  return snapshots;
}

+ (NSUInteger)captureRuntimeState {
  GULRuntimeSnapshot *snapshot = [[GULRuntimeSnapshot alloc] init];
  [snapshot capture];
  [[self snapshotCache] addObject:snapshot];
  return [self snapshotCache].count - 1;
}

+ (NSUInteger)captureRuntimeStateOfClasses:(NSSet<Class> *)classes {
  GULRuntimeSnapshot *snapshot = [[GULRuntimeSnapshot alloc] initWithClasses:classes];
  [snapshot capture];
  [[self snapshotCache] addObject:snapshot];
  return [self snapshotCache].count - 1;
}

+ (GULRuntimeDiff *)diffBetween:(NSUInteger)firstSnapshot
                 secondSnapshot:(NSUInteger)secondSnapshot {
  NSArray *snapshotCache = [self snapshotCache];
  return [snapshotCache[firstSnapshot] diff:snapshotCache[secondSnapshot]];
}

@end
