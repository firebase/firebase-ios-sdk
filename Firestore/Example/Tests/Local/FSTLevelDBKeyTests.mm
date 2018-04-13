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

#import "Firestore/Source/Local/FSTLevelDBKey.h"

#import <XCTest/XCTest.h>

#include <string>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace util = firebase::firestore::util;
namespace testutil = firebase::firestore::testutil;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBKeyTests : XCTestCase
@end

// I can't believe I have to write this...
bool StartsWith(const std::string &value, const std::string &prefix) {
  return prefix.size() <= value.size() && std::equal(prefix.begin(), prefix.end(), value.begin());
}

static std::string RemoteDocKey(NSString *pathString) {
  return [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:FSTTestDocKey(pathString)];
}

static std::string RemoteDocKeyPrefix(NSString *pathString) {
  return [FSTLevelDBRemoteDocumentKey
      keyPrefixWithResourcePath:testutil::Resource(util::MakeStringView(pathString))];
}

static std::string DocMutationKey(NSString *userID, NSString *key, FSTBatchID batchID) {
  return [FSTLevelDBDocumentMutationKey keyWithUserID:userID
                                          documentKey:FSTTestDocKey(key)
                                              batchID:batchID];
}

static std::string TargetDocKey(FSTTargetID targetID, NSString *key) {
  return [FSTLevelDBTargetDocumentKey keyWithTargetID:targetID documentKey:FSTTestDocKey(key)];
}

static std::string DocTargetKey(NSString *key, FSTTargetID targetID) {
  return [FSTLevelDBDocumentTargetKey keyWithDocumentKey:FSTTestDocKey(key) targetID:targetID];
}

/**
 * Asserts that the description for given key is equal to the expected description.
 *
 * @param key A StringView of a textual key
 * @param key An NSString that [FSTLevelDBKey descriptionForKey:] is expected to produce.
 */
#define FSTAssertExpectedKeyDescription(key, expectedDescription) \
  XCTAssertEqualObjects([FSTLevelDBKey descriptionForKey:(key)], (expectedDescription))

#define FSTAssertKeyLessThan(left, right)                                           \
  do {                                                                              \
    std::string leftKey = (left);                                                   \
    std::string rightKey = (right);                                                 \
    XCTAssertLessThan(leftKey.compare(right), 0, @"Expected %@ to be less than %@", \
                      [FSTLevelDBKey descriptionForKey:leftKey],                    \
                      [FSTLevelDBKey descriptionForKey:rightKey]);                  \
  } while (0)

@implementation FSTLevelDBKeyTests

- (void)testMutationKeyPrefixing {
  auto tableKey = [FSTLevelDBMutationKey keyPrefix];
  auto emptyUserKey = [FSTLevelDBMutationKey keyPrefixWithUserID:""];
  auto fooUserKey = [FSTLevelDBMutationKey keyPrefixWithUserID:"foo"];

  auto foo2Key = [FSTLevelDBMutationKey keyWithUserID:"foo" batchID:2];

  XCTAssertTrue(StartsWith(emptyUserKey, tableKey));

  // This is critical: prefixes of the a value don't convert into prefixes of the key.
  XCTAssertTrue(StartsWith(fooUserKey, tableKey));
  XCTAssertFalse(StartsWith(fooUserKey, emptyUserKey));

  // However whole segments in common are prefixes.
  XCTAssertTrue(StartsWith(foo2Key, tableKey));
  XCTAssertTrue(StartsWith(foo2Key, fooUserKey));
}

- (void)testMutationKeyEncodeDecodeCycle {
  FSTLevelDBMutationKey *key = [[FSTLevelDBMutationKey alloc] init];
  std::string user("foo");

  NSArray<NSNumber *> *batchIds = @[ @0, @1, @100, @(INT_MAX - 1), @(INT_MAX) ];
  for (NSNumber *batchIDNumber in batchIds) {
    FSTBatchID batchID = [batchIDNumber intValue];
    auto encoded = [FSTLevelDBMutationKey keyWithUserID:user batchID:batchID];

    BOOL ok = [key decodeKey:encoded];
    XCTAssertTrue(ok);
    XCTAssertEqual(key.userID, user);
    XCTAssertEqual(key.batchID, batchID);
  }
}

- (void)testMutationKeyDescription {
  FSTAssertExpectedKeyDescription([FSTLevelDBMutationKey keyPrefix], @"[mutation: incomplete key]");

  FSTAssertExpectedKeyDescription([FSTLevelDBMutationKey keyPrefixWithUserID:@"user1"],
                                  @"[mutation: userID=user1 incomplete key]");

  auto key = [FSTLevelDBMutationKey keyWithUserID:@"user1" batchID:42];
  FSTAssertExpectedKeyDescription(key, @"[mutation: userID=user1 batchID=42]");

  FSTAssertExpectedKeyDescription(key + " extra",
                                  @"[mutation: userID=user1 batchID=42 invalid "
                                  @"key=<hW11dGF0aW9uAAGNdXNlcjEAAYqqgCBleHRyYQ==>]");

  // Truncate the key so that it's missing its terminator.
  key.resize(key.size() - 1);
  FSTAssertExpectedKeyDescription(key, @"[mutation: userID=user1 batchID=42 incomplete key]");
}

- (void)testDocumentMutationKeyPrefixing {
  auto tableKey = [FSTLevelDBDocumentMutationKey keyPrefix];
  auto emptyUserKey = [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:""];
  auto fooUserKey = [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:"foo"];

  FSTDocumentKey *documentKey = FSTTestDocKey(@"foo/bar");
  auto foo2Key =
      [FSTLevelDBDocumentMutationKey keyWithUserID:"foo" documentKey:documentKey batchID:2];

  XCTAssertTrue(StartsWith(emptyUserKey, tableKey));

  // While we want a key with whole segments in common be considered a prefix it's vital that
  // partial segments in common not be prefixes.
  XCTAssertTrue(StartsWith(fooUserKey, tableKey));

  // Here even though "" is a prefix of "foo" that prefix is within a segment so keys derived from
  // those segments cannot be prefixes of each other.
  XCTAssertFalse(StartsWith(fooUserKey, emptyUserKey));
  XCTAssertFalse(StartsWith(emptyUserKey, fooUserKey));

  // However whole segments in common are prefixes.
  XCTAssertTrue(StartsWith(foo2Key, tableKey));
  XCTAssertTrue(StartsWith(foo2Key, fooUserKey));
}

- (void)testDocumentMutationKeyEncodeDecodeCycle {
  FSTLevelDBDocumentMutationKey *key = [[FSTLevelDBDocumentMutationKey alloc] init];
  std::string user("foo");

  NSArray<FSTDocumentKey *> *documentKeys = @[ FSTTestDocKey(@"a/b"), FSTTestDocKey(@"a/b/c/d") ];

  NSArray<NSNumber *> *batchIds = @[ @0, @1, @100, @(INT_MAX - 1), @(INT_MAX) ];
  for (NSNumber *batchIDNumber in batchIds) {
    for (FSTDocumentKey *documentKey in documentKeys) {
      FSTBatchID batchID = [batchIDNumber intValue];
      auto encoded = [FSTLevelDBDocumentMutationKey keyWithUserID:user
                                                      documentKey:documentKey
                                                          batchID:batchID];

      BOOL ok = [key decodeKey:encoded];
      XCTAssertTrue(ok);
      XCTAssertEqual(key.userID, user);
      XCTAssertEqualObjects(key.documentKey, documentKey);
      XCTAssertEqual(key.batchID, batchID);
    }
  }
}

- (void)testDocumentMutationKeyOrdering {
  // Different user:
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar", 0), DocMutationKey(@"10", @"foo/bar", 0));
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar", 0), DocMutationKey(@"2", @"foo/bar", 0));

  // Different paths:
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar", 0), DocMutationKey(@"1", @"foo/baz", 0));
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar", 0), DocMutationKey(@"1", @"foo/bar2", 0));
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar", 0),
                       DocMutationKey(@"1", @"foo/bar/suffix/key", 0));
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar/suffix/key", 0),
                       DocMutationKey(@"1", @"foo/bar2", 0));

  // Different batchID:
  FSTAssertKeyLessThan(DocMutationKey(@"1", @"foo/bar", 0), DocMutationKey(@"1", @"foo/bar", 1));
}

- (void)testDocumentMutationKeyDescription {
  FSTAssertExpectedKeyDescription([FSTLevelDBDocumentMutationKey keyPrefix],
                                  @"[document_mutation: incomplete key]");

  FSTAssertExpectedKeyDescription([FSTLevelDBDocumentMutationKey keyPrefixWithUserID:@"user1"],
                                  @"[document_mutation: userID=user1 incomplete key]");

  auto key = [FSTLevelDBDocumentMutationKey keyPrefixWithUserID:@"user1"
                                                   resourcePath:testutil::Resource("foo/bar")];
  FSTAssertExpectedKeyDescription(key,
                                  @"[document_mutation: userID=user1 key=foo/bar incomplete key]");

  key = [FSTLevelDBDocumentMutationKey keyWithUserID:@"user1"
                                         documentKey:FSTTestDocKey(@"foo/bar")
                                             batchID:42];
  FSTAssertExpectedKeyDescription(key, @"[document_mutation: userID=user1 key=foo/bar batchID=42]");
}

- (void)testTargetGlobalKeyEncodeDecodeCycle {
  FSTLevelDBTargetGlobalKey *key = [[FSTLevelDBTargetGlobalKey alloc] init];

  auto encoded = [FSTLevelDBTargetGlobalKey key];
  BOOL ok = [key decodeKey:encoded];
  XCTAssertTrue(ok);
}

- (void)testTargetGlobalKeyDescription {
  FSTAssertExpectedKeyDescription([FSTLevelDBTargetGlobalKey key], @"[target_global:]");
}

- (void)testTargetKeyEncodeDecodeCycle {
  FSTLevelDBTargetKey *key = [[FSTLevelDBTargetKey alloc] init];
  FSTTargetID targetID = 42;

  auto encoded = [FSTLevelDBTargetKey keyWithTargetID:42];
  BOOL ok = [key decodeKey:encoded];
  XCTAssertTrue(ok);
  XCTAssertEqual(key.targetID, targetID);
}

- (void)testTargetKeyDescription {
  FSTAssertExpectedKeyDescription([FSTLevelDBTargetKey keyWithTargetID:42],
                                  @"[target: targetID=42]");
}

- (void)testQueryTargetKeyEncodeDecodeCycle {
  FSTLevelDBQueryTargetKey *key = [[FSTLevelDBQueryTargetKey alloc] init];
  std::string canonicalID("foo");
  FSTTargetID targetID = 42;

  auto encoded = [FSTLevelDBQueryTargetKey keyWithCanonicalID:canonicalID targetID:42];
  BOOL ok = [key decodeKey:encoded];
  XCTAssertTrue(ok);
  XCTAssertEqual(key.canonicalID, canonicalID);
  XCTAssertEqual(key.targetID, targetID);
}

- (void)testQueryKeyDescription {
  FSTAssertExpectedKeyDescription([FSTLevelDBQueryTargetKey keyWithCanonicalID:"foo" targetID:42],
                                  @"[query_target: canonicalID=foo targetID=42]");
}

- (void)testTargetDocumentKeyEncodeDecodeCycle {
  FSTLevelDBTargetDocumentKey *key = [[FSTLevelDBTargetDocumentKey alloc] init];

  auto encoded =
      [FSTLevelDBTargetDocumentKey keyWithTargetID:42 documentKey:FSTTestDocKey(@"foo/bar")];
  BOOL ok = [key decodeKey:encoded];
  XCTAssertTrue(ok);
  XCTAssertEqual(key.targetID, 42);
  XCTAssertEqualObjects(key.documentKey, FSTTestDocKey(@"foo/bar"));
}

- (void)testTargetDocumentKeyOrdering {
  // Different targetID:
  FSTAssertKeyLessThan(TargetDocKey(1, @"foo/bar"), TargetDocKey(2, @"foo/bar"));
  FSTAssertKeyLessThan(TargetDocKey(2, @"foo/bar"), TargetDocKey(10, @"foo/bar"));
  FSTAssertKeyLessThan(TargetDocKey(10, @"foo/bar"), TargetDocKey(100, @"foo/bar"));
  FSTAssertKeyLessThan(TargetDocKey(42, @"foo/bar"), TargetDocKey(100, @"foo/bar"));

  // Different paths:
  FSTAssertKeyLessThan(TargetDocKey(1, @"foo/bar"), TargetDocKey(1, @"foo/baz"));
  FSTAssertKeyLessThan(TargetDocKey(1, @"foo/bar"), TargetDocKey(1, @"foo/bar2"));
  FSTAssertKeyLessThan(TargetDocKey(1, @"foo/bar"), TargetDocKey(1, @"foo/bar/suffix/key"));
  FSTAssertKeyLessThan(TargetDocKey(1, @"foo/bar/suffix/key"), TargetDocKey(1, @"foo/bar2"));
}

- (void)testTargetDocumentKeyDescription {
  auto key = [FSTLevelDBTargetDocumentKey keyWithTargetID:42 documentKey:FSTTestDocKey(@"foo/bar")];
  XCTAssertEqualObjects([FSTLevelDBKey descriptionForKey:key],
                        @"[target_document: targetID=42 key=foo/bar]");
}

- (void)testDocumentTargetKeyEncodeDecodeCycle {
  FSTLevelDBDocumentTargetKey *key = [[FSTLevelDBDocumentTargetKey alloc] init];

  auto encoded =
      [FSTLevelDBDocumentTargetKey keyWithDocumentKey:FSTTestDocKey(@"foo/bar") targetID:42];
  BOOL ok = [key decodeKey:encoded];
  XCTAssertTrue(ok);
  XCTAssertEqualObjects(key.documentKey, FSTTestDocKey(@"foo/bar"));
  XCTAssertEqual(key.targetID, 42);
}

- (void)testDocumentTargetKeyDescription {
  auto key = [FSTLevelDBDocumentTargetKey keyWithDocumentKey:FSTTestDocKey(@"foo/bar") targetID:42];
  XCTAssertEqualObjects([FSTLevelDBKey descriptionForKey:key],
                        @"[document_target: key=foo/bar targetID=42]");
}

- (void)testDocumentTargetKeyOrdering {
  // Different paths:
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 1), DocTargetKey(@"foo/baz", 1));
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 1), DocTargetKey(@"foo/bar2", 1));
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 1), DocTargetKey(@"foo/bar/suffix/key", 1));
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar/suffix/key", 1), DocTargetKey(@"foo/bar2", 1));

  // Different targetID:
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 1), DocTargetKey(@"foo/bar", 2));
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 2), DocTargetKey(@"foo/bar", 10));
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 10), DocTargetKey(@"foo/bar", 100));
  FSTAssertKeyLessThan(DocTargetKey(@"foo/bar", 42), DocTargetKey(@"foo/bar", 100));
}

- (void)testRemoteDocumentKeyPrefixing {
  auto tableKey = [FSTLevelDBRemoteDocumentKey keyPrefix];

  XCTAssertTrue(StartsWith(RemoteDocKey(@"foo/bar"), tableKey));

  // This is critical: foo/bar2 should not contain foo/bar.
  XCTAssertFalse(StartsWith(RemoteDocKey(@"foo/bar2"), RemoteDocKey(@"foo/bar")));

  // Prefixes must be encoded specially
  XCTAssertFalse(StartsWith(RemoteDocKey(@"foo/bar/baz/quu"), RemoteDocKey(@"foo/bar")));
  XCTAssertTrue(StartsWith(RemoteDocKey(@"foo/bar/baz/quu"), RemoteDocKeyPrefix(@"foo/bar")));
  XCTAssertTrue(StartsWith(RemoteDocKeyPrefix(@"foo/bar/baz/quu"), RemoteDocKeyPrefix(@"foo/bar")));
  XCTAssertTrue(StartsWith(RemoteDocKeyPrefix(@"foo/bar/baz"), RemoteDocKeyPrefix(@"foo/bar")));
  XCTAssertTrue(StartsWith(RemoteDocKeyPrefix(@"foo/bar"), RemoteDocKeyPrefix(@"foo")));
}

- (void)testRemoteDocumentKeyOrdering {
  FSTAssertKeyLessThan(RemoteDocKey(@"foo/bar"), RemoteDocKey(@"foo/bar2"));
  FSTAssertKeyLessThan(RemoteDocKey(@"foo/bar"), RemoteDocKey(@"foo/bar/suffix/key"));
}

- (void)testRemoteDocumentKeyEncodeDecodeCycle {
  FSTLevelDBRemoteDocumentKey *key = [[FSTLevelDBRemoteDocumentKey alloc] init];

  NSArray<NSString *> *paths = @[ @"foo/bar", @"foo/bar2", @"foo/bar/baz/quux" ];
  for (NSString *path in paths) {
    auto encoded = RemoteDocKey(path);
    BOOL ok = [key decodeKey:encoded];
    XCTAssertTrue(ok);
    XCTAssertEqualObjects(key.documentKey, FSTTestDocKey(path));
  }
}

- (void)testRemoteDocumentKeyDescription {
  FSTAssertExpectedKeyDescription(
      [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:FSTTestDocKey(@"foo/bar/baz/quux")],
      @"[remote_document: key=foo/bar/baz/quux]");
}

@end

#undef FSTAssertExpectedKeyDescription

NS_ASSUME_NONNULL_END
