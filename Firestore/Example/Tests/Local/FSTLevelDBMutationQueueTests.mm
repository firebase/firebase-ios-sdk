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

#import <XCTest/XCTest.h>

#include <string>
#include <vector>

#import "Firestore/Example/Tests/Local/FSTMutationQueueTests.h"
#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDB.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/reference_set.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "absl/strings/string_view.h"
#include "leveldb/db.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::auth::User;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbMutationQueue;
using firebase::firestore::local::LoadNextBatchIdFromDb;
using firebase::firestore::local::ReferenceSet;
using firebase::firestore::model::BatchId;
using firebase::firestore::util::OrderedCode;
using leveldb::DB;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;

// A dummy mutation value, useful for testing code that's known to examine only mutation keys.
static const char *kDummy = "1";

/**
 * Most of the tests for FSTLevelDBMutationQueue are performed on the FSTMutationQueue protocol in
 * FSTMutationQueueTests. This class is responsible for setting up the @a mutationQueue plus any
 * additional LevelDB-specific tests.
 */
@interface FSTLevelDBMutationQueueTests : FSTMutationQueueTests
@end

/**
 * Creates a key that's structurally the same as LevelDbMutationKey except it allows for
 * nonstandard table names.
 */
std::string MutationLikeKey(absl::string_view table, absl::string_view userID, BatchId batchID) {
  std::string key;
  OrderedCode::WriteString(&key, table);
  OrderedCode::WriteString(&key, userID);
  OrderedCode::WriteSignedNumIncreasing(&key, batchID);
  return key;
}

@implementation FSTLevelDBMutationQueueTests {
  FSTLevelDB *_db;
  ReferenceSet _additionalReferences;
}

- (void)setUp {
  [super setUp];
  _db = [FSTPersistenceTestHelpers levelDBPersistence];
  [_db.referenceDelegate addInMemoryPins:&_additionalReferences];

  self.mutationQueue = [_db mutationQueueForUser:User("user")];
  self.persistence = _db;

  self.persistence.run("Setup", [&]() { self.mutationQueue->Start(); });
}

- (void)testLoadNextBatchID_zeroWhenTotallyEmpty {
  // Initial seek is invalid
  XCTAssertEqual(LoadNextBatchIdFromDb(_db.ptr), 1);
}

- (void)testLoadNextBatchID_zeroWhenNoMutations {
  // Initial seek finds no mutations
  [self setDummyValueForKey:MutationLikeKey("mutationr", "foo", 20)];
  [self setDummyValueForKey:MutationLikeKey("mutationsa", "foo", 10)];
  XCTAssertEqual(LoadNextBatchIdFromDb(_db.ptr), 1);
}

- (void)testLoadNextBatchID_findsSingleRow {
  // Seeks off the end of the table altogether
  [self setDummyValueForKey:LevelDbMutationKey::Key("foo", 6)];

  XCTAssertEqual(LoadNextBatchIdFromDb(_db.ptr), 7);
}

- (void)testLoadNextBatchID_findsSingleRowAmongNonMutations {
  // Seeks into table following mutations.
  [self setDummyValueForKey:LevelDbMutationKey::Key("foo", 6)];
  [self setDummyValueForKey:MutationLikeKey("mutationsa", "foo", 10)];

  XCTAssertEqual(LoadNextBatchIdFromDb(_db.ptr), 7);
}

- (void)testLoadNextBatchID_findsMaxAcrossUsers {
  [self setDummyValueForKey:LevelDbMutationKey::Key("fo", 5)];
  [self setDummyValueForKey:LevelDbMutationKey::Key("food", 3)];

  [self setDummyValueForKey:LevelDbMutationKey::Key("foo", 6)];
  [self setDummyValueForKey:LevelDbMutationKey::Key("foo", 2)];
  [self setDummyValueForKey:LevelDbMutationKey::Key("foo", 1)];

  XCTAssertEqual(LoadNextBatchIdFromDb(_db.ptr), 7);
}

- (void)testLoadNextBatchID_onlyFindsMutations {
  // Write higher-valued batchIDs in nearby "tables"
  std::vector<std::string> tables{"mutatio", "mutationsa", "bears", "zombies"};
  BatchId highBatchID = 5;
  for (const auto &table : tables) {
    [self setDummyValueForKey:MutationLikeKey(table, "", highBatchID++)];
  }

  [self setDummyValueForKey:LevelDbMutationKey::Key("bar", 3)];
  [self setDummyValueForKey:LevelDbMutationKey::Key("bar", 2)];
  [self setDummyValueForKey:LevelDbMutationKey::Key("foo", 1)];

  // None of the higher tables should match -- this is the only entry that's in the mutations
  // table
  XCTAssertEqual(LoadNextBatchIdFromDb(_db.ptr), 4);
}

- (void)testEmptyProtoCanBeUpgraded {
  // An empty protocol buffer serializes to a zero-length byte buffer.
  GPBEmpty *empty = [GPBEmpty message];
  NSData *emptyData = [empty data];
  XCTAssertEqual(emptyData.length, 0);

  // Choose some other (arbitrary) proto and parse it from the empty message and it should all be
  // defaults. This shows that empty proto values within the index row value don't pose any future
  // liability.
  NSError *error;
  FSTPBMutationQueue *parsedMessage = [FSTPBMutationQueue parseFromData:emptyData error:&error];
  XCTAssertNil(error);

  FSTPBMutationQueue *defaultMessage = [FSTPBMutationQueue message];
  XCTAssertEqual(parsedMessage.lastAcknowledgedBatchId, defaultMessage.lastAcknowledgedBatchId);
  XCTAssertEqualObjects(parsedMessage.lastStreamToken, defaultMessage.lastStreamToken);
}

- (void)setDummyValueForKey:(const std::string &)key {
  _db.ptr->Put(WriteOptions(), key, kDummy);
}

@end

NS_ASSUME_NONNULL_END
