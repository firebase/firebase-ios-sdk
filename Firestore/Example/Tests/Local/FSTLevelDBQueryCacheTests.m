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

#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"

#import "Firestore/Source/Local/FSTLevelDB.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Example/Tests/Local/FSTQueryCacheTests.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBQueryCacheTests : FSTQueryCacheTests
@end

/**
 * The tests for FSTLevelDBQueryCache are performed on the FSTQueryCache protocol in
 * FSTQueryCacheTests. This class is merely responsible for setting up and tearing down the
 * @a queryCache.
 */
@implementation FSTLevelDBQueryCacheTests

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers levelDBPersistence];
  self.queryCache = [self.persistence queryCache];
  [self.queryCache start];
}

- (void)tearDown {
  [self.queryCache shutdown];
  self.persistence = nil;
  self.queryCache = nil;

  [super tearDown];
}

@end

NS_ASSUME_NONNULL_END
