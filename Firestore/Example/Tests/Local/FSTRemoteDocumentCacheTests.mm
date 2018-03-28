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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/strings/string_view.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;

NS_ASSUME_NONNULL_BEGIN

static const char *kDocPath = "a/b";
static const char *kLongDocPath = "a/b/c/d/e/f";
static const int kVersion = 42;

@implementation FSTRemoteDocumentCacheTests {
  NSDictionary<NSString *, id> *_kDocData;
}

- (void)setUp {
  [super setUp];

  // essentially a constant, but can't be a compile-time one.
  _kDocData = @{ @"a" : @1, @"b" : @2 };
}

- (void)testReadDocumentNotInCache {
  if (!self.remoteDocumentCache) return;

  XCTAssertNil([self readEntryAtPath:kDocPath]);
}

// Helper for next two tests.
- (void)setAndReadADocumentAtPath:(const absl::string_view)path {
  FSTDocument *written = [self setTestDocumentAtPath:path];
  FSTMaybeDocument *read = [self readEntryAtPath:path];
  XCTAssertEqualObjects(read, written);
}

- (void)testSetAndReadADocument {
  if (!self.remoteDocumentCache) return;

  [self setAndReadADocumentAtPath:kDocPath];
}

- (void)testSetAndReadADocumentAtDeepPath {
  if (!self.remoteDocumentCache) return;

  [self setAndReadADocumentAtPath:kLongDocPath];
}

- (void)testSetAndReadDeletedDocument {
  if (!self.remoteDocumentCache) return;

  FSTDeletedDocument *deletedDoc = FSTTestDeletedDoc(kDocPath, kVersion);
  [self addEntry:deletedDoc];

  XCTAssertEqualObjects([self readEntryAtPath:kDocPath], deletedDoc);
}

- (void)testSetDocumentToNewValue {
  if (!self.remoteDocumentCache) return;

  [self setTestDocumentAtPath:kDocPath];
  FSTDocument *newDoc = FSTTestDoc(kDocPath, kVersion, @{ @"data" : @2 }, NO);
  [self addEntry:newDoc];
  XCTAssertEqualObjects([self readEntryAtPath:kDocPath], newDoc);
}

- (void)testRemoveDocument {
  if (!self.remoteDocumentCache) return;

  [self setTestDocumentAtPath:kDocPath];
  [self removeEntryAtPath:kDocPath];

  XCTAssertNil([self readEntryAtPath:kDocPath]);
}

- (void)testRemoveNonExistentDocument {
  if (!self.remoteDocumentCache) return;

  // no-op, but make sure it doesn't throw.
  XCTAssertNoThrow([self removeEntryAtPath:kDocPath]);
}

// TODO(mikelehen): Write more elaborate tests once we have more elaborate implementations.
- (void)testDocumentsMatchingQuery {
  if (!self.remoteDocumentCache) return;

  // TODO(rsgowman): This just verifies that we do a prefix scan against the
  // query path. We'll need more tests once we add index support.
  [self setTestDocumentAtPath:"a/1"];
  [self setTestDocumentAtPath:"b/1"];
  [self setTestDocumentAtPath:"b/2"];
  [self setTestDocumentAtPath:"c/1"];

  FSTQuery *query = FSTTestQuery("b");
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"DocumentsMatchingQuery"];
  FSTDocumentDictionary *results = [self.remoteDocumentCache documentsMatchingQuery:query];
  NSArray *expected =
      @[ FSTTestDoc("b/1", kVersion, _kDocData, NO), FSTTestDoc("b/2", kVersion, _kDocData, NO) ];
  XCTAssertEqual([results count], [expected count]);
  for (FSTDocument *doc in expected) {
    XCTAssertEqualObjects([results objectForKey:doc.key], doc);
  }
  [self.persistence commitGroup:group];
}

#pragma mark - Helpers

- (FSTDocument *)setTestDocumentAtPath:(const absl::string_view)path {
  FSTDocument *doc = FSTTestDoc(path, kVersion, _kDocData, NO);
  [self addEntry:doc];
  return doc;
}

- (void)addEntry:(FSTMaybeDocument *)maybeDoc {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"addEntry"];
  [self.remoteDocumentCache addEntry:maybeDoc group:group];
  [self.persistence commitGroup:group];
}

- (FSTMaybeDocument *_Nullable)readEntryAtPath:(const absl::string_view)path {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"ReadEntryAtPath"];
  FSTMaybeDocument *result = [self.remoteDocumentCache entryForKey:testutil::Key(path)];
  [self.persistence commitGroup:group];
  return result;
}

- (void)removeEntryAtPath:(const absl::string_view)path {
  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"removeEntryAtPath"];
  [self.remoteDocumentCache removeEntryForKey:testutil::Key(path) group:group];
  [self.persistence commitGroup:group];
}

@end

NS_ASSUME_NONNULL_END
