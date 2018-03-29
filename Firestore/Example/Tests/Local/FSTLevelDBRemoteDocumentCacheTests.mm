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

#import "Firestore/Example/Tests/Local/FSTRemoteDocumentCacheTests.h"

#include <leveldb/db.h>

#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::WriteOptions;
using firebase::firestore::util::OrderedCode;

// A dummy document value, useful for testing code that's known to examine only document keys.
static const char *kDummy = "1";

/**
 * The tests for FSTLevelDBRemoteDocumentCache are performed on the FSTRemoteDocumentCache
 * protocol in FSTRemoteDocumentCacheTests. This class is merely responsible for setting up and
 * tearing down the @a remoteDocumentCache.
 */
@interface FSTLevelDBRemoteDocumentCacheTests : FSTRemoteDocumentCacheTests
@end

@implementation FSTLevelDBRemoteDocumentCacheTests {
  FSTLevelDB *_db;
}

- (void)setUp {
  [super setUp];
  _db = [FSTPersistenceTestHelpers levelDBPersistence];
  self.persistence = _db;
  self.remoteDocumentCache = [self.persistence remoteDocumentCache];

  // Write a couple dummy rows that should appear before/after the remote_documents table to make
  // sure the tests are unaffected.
  [self writeDummyRowWithSegments:@[ @"remote_documentr", @"foo", @"bar" ]];
  [self writeDummyRowWithSegments:@[ @"remote_documentsa", @"foo", @"bar" ]];
}

- (void)tearDown {
  self.remoteDocumentCache = nil;
  self.persistence = nil;
  _db = nil;
  [super tearDown];
}

- (void)writeDummyRowWithSegments:(NSArray<NSString *> *)segments {
  std::string key;
  for (NSString *segment in segments) {
    OrderedCode::WriteString(&key, segment.UTF8String);
  }

  _db.ptr->Put(WriteOptions(), key, kDummy);
}

@end

NS_ASSUME_NONNULL_END
