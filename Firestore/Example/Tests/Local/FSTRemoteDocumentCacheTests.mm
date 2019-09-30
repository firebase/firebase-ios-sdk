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
#include <vector>

#import "Firestore/Source/Local/FSTPersistence.h"

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
namespace core = firebase::firestore::core;
namespace util = firebase::firestore::util;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::OptionalMaybeDocumentMap;

using testutil::DeletedDoc;
using testutil::Doc;
using testutil::Map;
using testutil::Query;

NS_ASSUME_NONNULL_BEGIN

static const char *kDocPath = "a/b";
static const char *kLongDocPath = "a/b/c/d/e/f";
static const int kVersion = 42;

void ExpectMapHasDocs(XCTestCase *self,
                      const MaybeDocumentMap &map,
                      const std::vector<Document> &expected,
                      bool exactly) {
  if (exactly) {
    XCTAssertEqual(map.size(), expected.size());
  }
  for (const Document &doc : expected) {
    absl::optional<MaybeDocument> actual = map.get(doc.key());
    XCTAssertTrue(actual.has_value());
    XCTAssertEqual(*actual, doc);
  }
}

void ExpectMapHasDocs(XCTestCase *self,
                      const OptionalMaybeDocumentMap &map,
                      const std::vector<Document> &expected,
                      bool exactly) {
  if (exactly) {
    XCTAssertEqual(map.size(), expected.size());
  }
  for (const Document &doc : expected) {
    absl::optional<absl::optional<MaybeDocument>> actual = map.get(doc.key());
    XCTAssertTrue(actual.has_value());
    XCTAssertEqual(**actual, doc);
  }
}

@implementation FSTRemoteDocumentCacheTests {
  FieldValue::Map _kDocData;
}

- (void)setUp {
  [super setUp];

  // essentially a constant, but can't be a compile-time one.
  _kDocData = Map("a", 1, "b", 2);
}

- (void)tearDown {
  [self.persistence shutdown];
}

- (void)testReadDocumentNotInCache {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testReadDocumentNotInCache", [&] {
    XCTAssertEqual(absl::nullopt, self.remoteDocumentCache->Get(testutil::Key(kDocPath)));
  });
}

// Helper for next two tests.
- (void)setAndReadADocumentAtPath:(const absl::string_view)path {
  self.persistence.run("setAndReadADocumentAtPath", [&] {
    Document written = [self setTestDocumentAtPath:path];
    absl::optional<MaybeDocument> read = self.remoteDocumentCache->Get(testutil::Key(path));
    XCTAssertEqual(*read, written);
  });
}

- (void)testSetAndReadADocument {
  if (!self.remoteDocumentCache) return;

  [self setAndReadADocumentAtPath:kDocPath];
}

- (void)testSetAndReadSeveralDocuments {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetAndReadSeveralDocuments", [=] {
    std::vector<Document> written = {
        [self setTestDocumentAtPath:kDocPath],
        [self setTestDocumentAtPath:kLongDocPath],
    };
    OptionalMaybeDocumentMap read = self.remoteDocumentCache->GetAll(
        DocumentKeySet{testutil::Key(kDocPath), testutil::Key(kLongDocPath)});
    ExpectMapHasDocs(self, read, written, /* exactly= */ true);
  });
}

- (void)testSetAndReadSeveralDocumentsIncludingMissingDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetAndReadSeveralDocumentsIncludingMissingDocument", [=] {
    std::vector<Document> written = {
        [self setTestDocumentAtPath:kDocPath],
        [self setTestDocumentAtPath:kLongDocPath],
    };
    OptionalMaybeDocumentMap read = self.remoteDocumentCache->GetAll(DocumentKeySet{
        testutil::Key(kDocPath),
        testutil::Key(kLongDocPath),
        testutil::Key("foo/nonexistent"),
    });
    ExpectMapHasDocs(self, read, written, /* exactly= */ false);
    auto found = read.find(DocumentKey::FromPathString("foo/nonexistent"));
    XCTAssertTrue(found != read.end());
    XCTAssertEqual(absl::nullopt, found->second);
  });
}

- (void)testSetAndReadADocumentAtDeepPath {
  if (!self.remoteDocumentCache) return;

  [self setAndReadADocumentAtPath:kLongDocPath];
}

- (void)testSetAndReadDeletedDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetAndReadDeletedDocument", [&] {
    absl::optional<MaybeDocument> deletedDoc = DeletedDoc(kDocPath, kVersion);
    self.remoteDocumentCache->Add(*deletedDoc);

    XCTAssertEqual(self.remoteDocumentCache->Get(testutil::Key(kDocPath)), deletedDoc);
  });
}

- (void)testSetDocumentToNewValue {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testSetDocumentToNewValue", [&] {
    [self setTestDocumentAtPath:kDocPath];
    absl::optional<MaybeDocument> newDoc = Doc(kDocPath, kVersion, Map("data", 2));
    self.remoteDocumentCache->Add(*newDoc);
    XCTAssertEqual(self.remoteDocumentCache->Get(testutil::Key(kDocPath)), newDoc);
  });
}

- (void)testRemoveDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testRemoveDocument", [&] {
    [self setTestDocumentAtPath:kDocPath];
    self.remoteDocumentCache->Remove(testutil::Key(kDocPath));

    XCTAssertEqual(self.remoteDocumentCache->Get(testutil::Key(kDocPath)), absl::nullopt);
  });
}

- (void)testRemoveNonExistentDocument {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testRemoveNonExistentDocument", [&] {
    // no-op, but make sure it doesn't throw.
    XCTAssertNoThrow(self.remoteDocumentCache->Remove(testutil::Key(kDocPath)));
  });
}

// TODO(mikelehen): Write more elaborate tests once we have more elaborate implementations.
- (void)testDocumentsMatchingQuery {
  if (!self.remoteDocumentCache) return;

  self.persistence.run("testDocumentsMatchingQuery", [&] {
    // TODO(rsgowman): This just verifies that we do a prefix scan against the
    // query path. We'll need more tests once we add index support.
    [self setTestDocumentAtPath:"a/1"];
    [self setTestDocumentAtPath:"b/1"];
    [self setTestDocumentAtPath:"b/1/z/1"];
    [self setTestDocumentAtPath:"b/2"];
    [self setTestDocumentAtPath:"c/1"];

    core::Query query = Query("b");
    DocumentMap results = self.remoteDocumentCache->GetMatching(query);
    std::vector<Document> docs = {
        Doc("b/1", kVersion, _kDocData),
        Doc("b/2", kVersion, _kDocData),
    };
    ExpectMapHasDocs(self, results.underlying_map(), docs, /* exactly= */ true);
  });
}

#pragma mark - Helpers
- (Document)setTestDocumentAtPath:(const absl::string_view)path {
  Document doc = Doc(path, kVersion, _kDocData);
  self.remoteDocumentCache->Add(doc);
  return doc;
}

@end

NS_ASSUME_NONNULL_END
