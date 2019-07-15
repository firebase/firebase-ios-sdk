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

#include <memory>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/local/memory_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/strings/string_view.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::MaybeDocumentMap;

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
  _kDocData = @{@"a" : @1, @"b" : @2};
}

- (void)tearDown {
  [self.persistence shutdown];
}

- (void)testReadDocumentNotInCache {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testReadDocumentNotInCache", [&]() {
    XCTAssertNil(self.remoteDocumentCache->Get(testutil::Key(kDocPath)));
  });
}

// Helper for next two tests.
- (void)setAndReadADocumentAtPath:(const absl::string_view)path {
  self.persistence.run("setAndReadADocumentAtPath", [&]() {
    FSTDocument *written = [self setTestDocumentAtPath:path];
    FSTMaybeDocument *read = self.remoteDocumentCache->Get(testutil::Key(path));
    XCTAssertEqualObjects(read, written);
  });
}

- (void)testSetAndReadADocument {
  if (!self.remoteDocumentCache) return;

  [self setAndReadADocumentAtPath:kDocPath];
}

- (void)testSetAndReadSeveralDocuments {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetAndReadSeveralDocuments", [=]() {
    NSArray<FSTDocument *> *written =
        @[ [self setTestDocumentAtPath:kDocPath], [self setTestDocumentAtPath:kLongDocPath] ];
    MaybeDocumentMap read = self.remoteDocumentCache->GetAll(
        DocumentKeySet{testutil::Key(kDocPath), testutil::Key(kLongDocPath)});
    [self expectMap:read hasDocsInArray:written exactly:YES];
  });
}

- (void)testSetAndReadSeveralDocumentsIncludingMissingDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetAndReadSeveralDocumentsIncludingMissingDocument", [=]() {
    NSArray<FSTDocument *> *written =
        @[ [self setTestDocumentAtPath:kDocPath], [self setTestDocumentAtPath:kLongDocPath] ];
    MaybeDocumentMap read = self.remoteDocumentCache->GetAll(DocumentKeySet{
        testutil::Key(kDocPath),
        testutil::Key(kLongDocPath),
        testutil::Key("foo/nonexistent"),
    });
    [self expectMap:read hasDocsInArray:written exactly:NO];
    auto found = read.find(DocumentKey::FromPathString("foo/nonexistent"));
    XCTAssertTrue(found != read.end());
    XCTAssertNil(found->second);
  });
}

- (void)testSetAndReadADocumentAtDeepPath {
  if (!self.remoteDocumentCache) return;

  [self setAndReadADocumentAtPath:kLongDocPath];
}

- (void)testSetAndReadDeletedDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetAndReadDeletedDocument", [&]() {
    FSTDeletedDocument *deletedDoc = FSTTestDeletedDoc(kDocPath, kVersion, NO);
    self.remoteDocumentCache->Add(deletedDoc);

    XCTAssertEqualObjects(self.remoteDocumentCache->Get(testutil::Key(kDocPath)), deletedDoc);
  });
}

- (void)testSetDocumentToNewValue {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetDocumentToNewValue", [&]() {
    [self setTestDocumentAtPath:kDocPath];
    FSTDocument *newDoc = FSTTestDoc(kDocPath, kVersion, @{@"data" : @2}, DocumentState::kSynced);
    self.remoteDocumentCache->Add(newDoc);
    XCTAssertEqualObjects(self.remoteDocumentCache->Get(testutil::Key(kDocPath)), newDoc);
  });
}

- (void)testRemoveDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testRemoveDocument", [&]() {
    [self setTestDocumentAtPath:kDocPath];
    self.remoteDocumentCache->Remove(testutil::Key(kDocPath));

    XCTAssertNil(self.remoteDocumentCache->Get(testutil::Key(kDocPath)));
  });
}

- (void)testRemoveNonExistentDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testRemoveNonExistentDocument", [&]() {
    // no-op, but make sure it doesn't throw.
    XCTAssertNoThrow(self.remoteDocumentCache->Remove(testutil::Key(kDocPath)));
  });
}

// TODO(mikelehen): Write more elaborate tests once we have more elaborate implementations.
- (void)testDocumentsMatchingQuery {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testDocumentsMatchingQuery", [&]() {
    // TODO(rsgowman): This just verifies that we do a prefix scan against the
    // query path. We'll need more tests once we add index support.
    [self setTestDocumentAtPath:"a/1"];
    [self setTestDocumentAtPath:"b/1"];
    [self setTestDocumentAtPath:"b/1/z/1"];
    [self setTestDocumentAtPath:"b/2"];
    [self setTestDocumentAtPath:"c/1"];

    FSTQuery *query = FSTTestQuery("b");
    DocumentMap results = self.remoteDocumentCache->GetMatching(query);
    [self expectMap:results.underlying_map()
        hasDocsInArray:@[
          FSTTestDoc("b/1", kVersion, _kDocData, DocumentState::kSynced),
          FSTTestDoc("b/2", kVersion, _kDocData, DocumentState::kSynced)
        ]
               exactly:YES];
  });
}

#pragma mark - Helpers
- (FSTDocument *)setTestDocumentAtPath:(const absl::string_view)path {
  FSTDocument *doc = FSTTestDoc(path, kVersion, _kDocData, DocumentState::kSynced);
  self.remoteDocumentCache->Add(doc);
  return doc;
}

- (void)expectMap:(const MaybeDocumentMap &)map
    hasDocsInArray:(NSArray<FSTDocument *> *)expected
           exactly:(BOOL)exactly {
  if (exactly) {
    XCTAssertEqual(map.size(), [expected count]);
  }
  for (FSTDocument *doc in expected) {
    FSTDocument *actual = nil;
    auto found = map.find(doc.key);
    if (found != map.end()) {
      actual = static_cast<FSTDocument *>(found->second);
    }
    XCTAssertEqualObjects(actual, doc);
  }
}

@end

NS_ASSUME_NONNULL_END
