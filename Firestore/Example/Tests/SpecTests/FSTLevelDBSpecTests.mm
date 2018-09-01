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

#import "Firestore/Example/Tests/SpecTests/FSTSpecTests.h"

#import "Firestore/Source/Local/FSTLevelDB.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Example/Tests/SpecTests/FSTSyncEngineTestDriver.h"

using firebase::firestore::util::Path;

NS_ASSUME_NONNULL_BEGIN

/**
 * An implementation of FSTSpecTests that uses the LevelDB implementation of local storage.
 *
 * See the FSTSpecTests class comments for more information about how this works.
 */
@interface FSTLevelDBSpecTests : FSTSpecTests
@end

@implementation FSTLevelDBSpecTests {
  Path _levelDbDir;
}

- (void)setUpForSpecWithConfig:(NSDictionary *)config {
  // Getting a new directory will ensure that it is empty.
  _levelDbDir = [FSTPersistenceTestHelpers levelDBDir];
  [super setUpForSpecWithConfig:config];
}

/** Overrides -[FSTSpecTests persistence] */
- (id<FSTPersistence>)persistenceWithGCEnabled:(__unused BOOL)GCEnabled {
  return [FSTPersistenceTestHelpers levelDBPersistenceWithDir:_levelDbDir];
}

- (BOOL)shouldRunWithTags:(NSArray<NSString *> *)tags {
  if ([tags containsObject:kEagerGC]) {
    return NO;
  }

  return [super shouldRunWithTags:tags];
}

@end

NS_ASSUME_NONNULL_END
