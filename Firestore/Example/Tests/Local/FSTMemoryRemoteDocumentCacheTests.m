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

#import "Local/FSTMemoryRemoteDocumentCache.h"

#import "Local/FSTMemoryPersistence.h"

#import "FSTPersistenceTestHelpers.h"
#import "FSTRemoteDocumentCacheTests.h"

@interface FSTMemoryRemoteDocumentCacheTests : FSTRemoteDocumentCacheTests
@end

/**
 * The tests for FSTMemoryRemoteDocumentCache are performed on the FSTRemoteDocumentCache
 * protocol in FSTRemoteDocumentCacheTests. This class is merely responsible for setting up and
 * tearing down the @a remoteDocumentCache.
 */
@implementation FSTMemoryRemoteDocumentCacheTests

- (void)setUp {
  [super setUp];

  self.persistence = [FSTPersistenceTestHelpers memoryPersistence];
  self.remoteDocumentCache = [self.persistence remoteDocumentCache];
}

- (void)tearDown {
  [self.remoteDocumentCache shutdown];
  self.persistence = nil;
  self.remoteDocumentCache = nil;

  [super tearDown];
}

@end
