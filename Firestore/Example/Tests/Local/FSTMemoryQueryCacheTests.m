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

#import "Local/FSTMemoryQueryCache.h"

#import "Local/FSTMemoryPersistence.h"

#import "FSTPersistenceTestHelpers.h"
#import "FSTQueryCacheTests.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryQueryCacheTests : FSTQueryCacheTests
@end

/**
 * The tests for FSTMemoryQueryCache are performed on the FSTQueryCache protocol in
 * FSTQueryCacheTests. This class is merely responsible for setting up and tearing down the
 * @a queryCache.
 */
@implementation FSTMemoryQueryCacheTests

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers memoryPersistence];
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
