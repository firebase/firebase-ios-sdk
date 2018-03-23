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

#import "Firestore/Source/Local/FSTWriteGroup.h"

#import <XCTest/XCTest.h>
#include <leveldb/db.h>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

using leveldb::ReadOptions;
using leveldb::Status;

NS_ASSUME_NONNULL_BEGIN

@interface FSTWriteGroupTests : XCTestCase
@end

@implementation FSTWriteGroupTests {
  FSTLevelDB *_db;
}

- (void)setUp {
  [super setUp];

  _db = [FSTPersistenceTestHelpers levelDBPersistence];
}

- (void)tearDown {
  _db = nil;

  [super tearDown];
}

- (void)testCommit {
  std::string key = [FSTLevelDBMutationKey keyWithUserID:"user1" batchID:42];
  FSTPBWriteBatch *message = [FSTPBWriteBatch message];
  message.batchId = 42;

  // This is a test that shows that committing an empty group does not fail. There are no side
  // effects to verify though.
  FSTWriteGroup *group = [_db startGroupWithAction:@"Empty commit"];
  XCTAssertNoThrow([_db commitGroup:group]);

  group = [_db startGroupWithAction:@"Put"];
  [group setMessage:message forKey:key];

  std::string value;
  Status status = _db.ptr->Get(ReadOptions(), key, &value);
  XCTAssertTrue(status.IsNotFound());

  [_db commitGroup:group];
  status = _db.ptr->Get(ReadOptions(), key, &value);
  XCTAssertTrue(status.ok());

  group = [_db startGroupWithAction:@"Delete"];
  [group removeMessageForKey:key];
  status = _db.ptr->Get(ReadOptions(), key, &value);
  XCTAssertTrue(status.ok());

  [_db commitGroup:group];
  status = _db.ptr->Get(ReadOptions(), key, &value);
  XCTAssertTrue(status.IsNotFound());
}

- (void)testCommittingWrongGroupThrows {
  // If you don't create the group through persistence, it should throw.
  FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"group"];
  XCTAssertThrows([_db commitGroup:group]);
}

- (void)testCommittingTwiceThrows {
  FSTWriteGroup *group = [_db startGroupWithAction:@"group"];
  [_db commitGroup:group];
  XCTAssertThrows([_db commitGroup:group]);
}

- (void)testNestingGroupsThrows {
  [_db startGroupWithAction:@"group1"];
  XCTAssertThrows([_db startGroupWithAction:@"group2"]);
}
@end

NS_ASSUME_NONNULL_END
