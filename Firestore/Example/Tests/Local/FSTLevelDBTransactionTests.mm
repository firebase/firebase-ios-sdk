/*
 * Copyright 2018 Google
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

#include <memory>
#include <string>

// This is out of order to satisfy the linter, which doesn't realize this is
// the header corresponding to this test.
// TODO(wilhuff): move this to the top once the test filename matches
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "absl/strings/string_view.h"
#include "leveldb/db.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::DB;
using leveldb::Options;
using leveldb::ReadOptions;
using leveldb::WriteOptions;
using leveldb::Status;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbTransaction;

@interface FSTLevelDBTransactionTests : XCTestCase
@end

@implementation FSTLevelDBTransactionTests {
  std::shared_ptr<DB> _db;
}

- (void)setUp {
  Options options;
  options.error_if_exists = true;
  options.create_if_missing = true;

  NSString *dir = [FSTPersistenceTestHelpers levelDBDir];
  DB *db;
  Status status = DB::Open(options, [dir UTF8String], &db);
  XCTAssert(status.ok(), @"Failed to create db: %s", status.ToString().c_str());
  _db.reset(db);
}

- (void)tearDown {
  _db.reset();
}

- (void)testCreateTransaction {
  LevelDbTransaction transaction(_db.get(), "testCreateTransaction");
  std::string key = "key1";

  transaction.Put(key, "value");
  auto iter = transaction.NewIterator();
  iter->Seek(key);
  XCTAssertEqual(key, iter->key());
  iter->Next();
  XCTAssertFalse(iter->Valid());
}

- (void)testCanReadCommittedAndMutations {
  const std::string committed_key1 = "c_key1";
  const std::string committed_value1 = "c_value1";
  const WriteOptions &writeOptions = LevelDbTransaction::DefaultWriteOptions();
  // add two things committed, mutate one, add another mutation
  // verify you can get the original committed, the mutation, and the addition
  Status status = _db->Put(writeOptions, committed_key1, committed_value1);
  XCTAssertTrue(status.ok());

  const std::string committed_key2 = "c_key2";
  const std::string committed_value2 = "c_value2";
  status = _db->Put(writeOptions, committed_key2, committed_value2);
  XCTAssertTrue(status.ok());

  LevelDbTransaction transaction(_db.get(), "testCanReadCommittedAndMutations");
  const std::string mutation_key1 = "m_key1";
  const std::string mutation_value1 = "m_value1";
  transaction.Put(mutation_key1, mutation_value1);

  const std::string mutation_key2 = committed_key2;
  const std::string mutation_value2 = "m_value2";
  transaction.Put(mutation_key2, mutation_value2);

  std::string value;
  status = transaction.Get(committed_key1, &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, committed_value1);

  status = transaction.Get(mutation_key1, &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, mutation_value1);

  status = transaction.Get(committed_key2, &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, mutation_value2);
}

- (void)testDeleteCommitted {
  // add something committed, delete it, verify you can't read it
  for (int i = 0; i < 3; ++i) {
    Status status = _db->Put(LevelDbTransaction::DefaultWriteOptions(), "key_" + std::to_string(i),
                             "value_" + std::to_string(i));
    XCTAssertTrue(status.ok());
  }
  LevelDbTransaction transaction(_db.get(), "testDeleteCommitted");
  transaction.Put("key_1", "new_value");
  std::string value;
  Status status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, "new_value");

  transaction.Delete("key_1");
  status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.IsNotFound());

  LevelDbTransaction::Iterator iter(&transaction);
  iter.Seek("");
  XCTAssertEqual(iter.key(), "key_0");
  iter.Next();
  XCTAssertEqual(iter.key(), "key_2");
  iter.Next();
  XCTAssertFalse(iter.Valid());
}

- (void)testMutateDeleted {
  // delete something, then mutate it, then read it.
  // Also include an actual deletion
  for (int i = 0; i < 4; ++i) {
    Status status = _db->Put(LevelDbTransaction::DefaultWriteOptions(), "key_" + std::to_string(i),
                             "value_" + std::to_string(i));
    XCTAssertTrue(status.ok());
  }
  std::string value;
  LevelDbTransaction transaction(_db.get(), "testMutateDeleted");
  transaction.Delete("key_1");
  Status status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.IsNotFound());

  transaction.Put("key_1", "new_value");
  status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, "new_value");

  transaction.Delete("key_3");

  LevelDbTransaction::Iterator iter(&transaction);
  iter.Seek("");
  XCTAssertEqual(iter.key(), "key_0");
  iter.Next();
  XCTAssertEqual(iter.key(), "key_1");
  XCTAssertEqual(iter.value(), "new_value");
  iter.Next();
  XCTAssertEqual(iter.key(), "key_2");
  iter.Next();
  XCTAssertFalse(iter.Valid());

  // Commit, then check underlying db.
  transaction.Commit();

  const ReadOptions &readOptions = LevelDbTransaction::DefaultReadOptions();
  status = _db->Get(readOptions, "key_0", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual("value_0", value);

  status = _db->Get(readOptions, "key_1", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual("new_value", value);

  status = _db->Get(readOptions, "key_2", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual("value_2", value);

  status = _db->Get(readOptions, "key_3", &value);
  XCTAssertTrue(status.IsNotFound());
}

- (void)testProtobufSupport {
  LevelDbTransaction transaction(_db.get(), "testProtobufSupport");

  FSTPBTarget *target = [FSTPBTarget message];
  target.targetId = 1;
  target.lastListenSequenceNumber = 2;

  std::string key("theKey");
  transaction.Put(key, target);

  std::string value;
  Status status = transaction.Get("theKey", &value);
  NSData *result =
      [[NSData alloc] initWithBytesNoCopy:(void *)value.data() length:value.size() freeWhenDone:NO];
  NSError *error;
  FSTPBTarget *parsed = [FSTPBTarget parseFromData:result error:&error];
  XCTAssertNil(error);
  XCTAssertTrue([target isEqual:parsed]);
}

- (void)testCanIterateAndDelete {
  LevelDbTransaction transaction(_db.get(), "testCanIterateAndDelete");

  for (int i = 0; i < 4; ++i) {
    transaction.Put("key_" + std::to_string(i), "value_" + std::to_string(i));
  }

  auto it = transaction.NewIterator();
  it->Seek("key_0");
  for (int i = 0; i < 4; ++i) {
    XCTAssertTrue(it->Valid());
    const absl::string_view &key = it->key();
    std::string expected = "key_" + std::to_string(i);
    XCTAssertEqual(expected, key);
    transaction.Delete(key);
    it->Next();
  }
}

- (void)testCanIterateFromDeletionToCommitted {
  // Write keys key_0 and key_1
  for (int i = 0; i < 2; ++i) {
    Status status = _db->Put(LevelDbTransaction::DefaultWriteOptions(), "key_" + std::to_string(i),
                             "value_" + std::to_string(i));
    XCTAssertTrue(status.ok());
  }

  // Create a transaction, iterate, deleting key_0. Verify we still iterate key_1.
  LevelDbTransaction transaction(_db.get(), "testCanIterateFromDeletionToCommitted");
  auto it = transaction.NewIterator();
  it->Seek("key_0");
  XCTAssertTrue(it->Valid());
  XCTAssertEqual("key_0", it->key());
  transaction.Delete("key_0");
  it->Next();
  XCTAssertTrue(it->Valid());
  XCTAssertEqual("key_1", it->key());
  it->Next();
  XCTAssertFalse(it->Valid());
}

- (void)testDeletingAheadOfAnIterator {
  // Write keys
  for (int i = 0; i < 4; ++i) {
    Status status = _db->Put(LevelDbTransaction::DefaultWriteOptions(), "key_" + std::to_string(i),
                             "value_" + std::to_string(i));
    XCTAssertTrue(status.ok());
  }

  // Create a transaction, iterate to key_1, delete key_2. Verify we still iterate key_3.
  LevelDbTransaction transaction(_db.get(), "testDeletingAheadOfAnIterator");
  auto it = transaction.NewIterator();
  it->Seek("key_0");
  XCTAssertTrue(it->Valid());
  XCTAssertEqual("key_0", it->key());
  it->Next();
  XCTAssertTrue(it->Valid());
  XCTAssertEqual("key_1", it->key());
  transaction.Delete("key_2");
  it->Next();
  XCTAssertTrue(it->Valid());
  XCTAssertEqual("key_3", it->key());
  XCTAssertTrue(it->Valid());
  it->Next();
  XCTAssertFalse(it->Valid());
}

- (void)testToString {
  std::string key = LevelDbMutationKey::Key("user1", 42);
  FSTPBWriteBatch *message = [FSTPBWriteBatch message];
  message.batchId = 42;

  LevelDbTransaction transaction(_db.get(), "testToString");
  std::string description = transaction.ToString();
  XCTAssertEqual(description, "<LevelDbTransaction testToString: 0 changes (0 bytes):>");

  transaction.Put(key, message);
  description = transaction.ToString();
  XCTAssertEqual(description,
                 "<LevelDbTransaction testToString: 1 changes (2 bytes):\n"
                 "  - Put [mutation: user_id=user1 batch_id=42] (2 bytes)>");

  std::string key2 = LevelDbMutationKey::Key("user1", 43);
  transaction.Delete(key2);
  description = transaction.ToString();
  XCTAssertEqual(description,
                 "<LevelDbTransaction testToString: 2 changes (2 bytes):\n"
                 "  - Delete [mutation: user_id=user1 batch_id=43]\n"
                 "  - Put [mutation: user_id=user1 batch_id=42] (2 bytes)>");
}

@end

NS_ASSUME_NONNULL_END
