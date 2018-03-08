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

#import "Firestore/Source/Local/FSTLevelDBMutationQueue.h"

#import <XCTest/XCTest.h>
#include <leveldb/db.h>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"

#import "Firestore/Example/Tests/Local/FSTMutationQueueTests.h"
#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::DB;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;
using Firestore::StringView;
using firebase::firestore::auth::User;
using firebase::firestore::util::OrderedCode;

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
 * Creates a key that's structurally the same as FSTLevelDBMutationKey except it allows for
 * nonstandard table names.
 */
std::string MutationLikeKey(StringView table, StringView userID, FSTBatchID batchID) {
  std::string key;
  OrderedCode::WriteString(&key, table);
  OrderedCode::WriteString(&key, userID);
  OrderedCode::WriteSignedNumIncreasing(&key, batchID);
  return key;
}

@implementation FSTLevelDBMutationQueueTests {
  FSTLevelDB *_db;
}

- (void)setUp {
  [super setUp];
  _db = [FSTPersistenceTestHelpers levelDBPersistence];
  self.mutationQueue = [_db mutationQueueForUser:User("user")];
  self.persistence = _db;

  FSTWriteGroup *group = [self.persistence startGroupWithAction:@"Start MutationQueue"];
  [self.mutationQueue startWithGroup:group];
  [self.persistence commitGroup:group];
}

- (void)testLoadNextBatchID_zeroWhenTotallyEmpty {
  // Initial seek is invalid
  XCTAssertEqual([FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr], 0);
}

- (void)testLoadNextBatchID_zeroWhenNoMutations {
  // Initial seek finds no mutations
  [self setDummyValueForKey:MutationLikeKey("mutationr", "foo", 20)];
  [self setDummyValueForKey:MutationLikeKey("mutationsa", "foo", 10)];
  XCTAssertEqual([FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr], 0);
}

- (void)testLoadNextBatchID_findsSingleRow {
  // Seeks off the end of the table altogether
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"foo" batchID:6]];

  XCTAssertEqual([FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr], 7);
}

- (void)testLoadNextBatchID_findsSingleRowAmongNonMutations {
  // Seeks into table following mutations.
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"foo" batchID:6]];
  [self setDummyValueForKey:MutationLikeKey("mutationsa", "foo", 10)];

  XCTAssertEqual([FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr], 7);
}

- (void)testLoadNextBatchID_findsMaxAcrossUsers {
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"fo" batchID:5]];
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"food" batchID:3]];

  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"foo" batchID:6]];
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"foo" batchID:2]];
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"foo" batchID:1]];

  XCTAssertEqual([FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr], 7);
}

- (void)testLoadNextBatchID_onlyFindsMutations {
  // Write higher-valued batchIDs in nearby "tables"
  auto tables = @[ @"mutatio", @"mutationsa", @"bears", @"zombies" ];
  FSTBatchID highBatchID = 5;
  for (NSString *table in tables) {
    [self setDummyValueForKey:MutationLikeKey(table, "", highBatchID++)];
  }

  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"bar" batchID:3]];
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"bar" batchID:2]];
  [self setDummyValueForKey:[FSTLevelDBMutationKey keyWithUserID:@"foo" batchID:1]];

  // None of the higher tables should match -- this is the only entry that's in the mutations
  // table
  XCTAssertEqual([FSTLevelDBMutationQueue loadNextBatchIDFromDB:_db.ptr], 4);
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
