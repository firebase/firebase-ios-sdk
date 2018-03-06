
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
#include <leveldb/db.h>
#import <Firestore/Protos/objc/firestore/local/Target.pbobjc.h>

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#include "Firestore/core/include/firebase/firestore/local/leveldb_transaction.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::DB;
using leveldb::Options;
using leveldb::ReadOptions;
using leveldb::WriteOptions;
using leveldb::Status;
using firebase::firestore::local::LevelDBTransaction;

@interface FSTLevelDBTransactionTests : XCTestCase
@end

@implementation FSTLevelDBTransactionTests {
  std::shared_ptr<DB> _db;
  ReadOptions _readOptions;
  WriteOptions _writeOptions;
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
  LevelDBTransaction transaction(_db, _readOptions, _writeOptions);
  std::string key = "key1";

  transaction.Put(key, "value");
  std::unique_ptr<LevelDBTransaction::Iterator> iter(transaction.NewIterator());
  iter->Seek(key);
  XCTAssertEqual(key, iter->key());
  iter->Next();
  XCTAssertFalse(iter->Valid());
}

- (void)testCanReadCommittedAndMutations {
  const std::string committed_key1 = "c_key1";
  const std::string committed_value1 = "c_value1";
  // add two things committed, mutate one, add another mutation
  // verify you can get the original committed, the mutation, and the addition
  Status status = _db->Put(_writeOptions, committed_key1, committed_value1);
  XCTAssertTrue(status.ok());

  const std::string committed_key2 = "c_key2";
  const std::string committed_value2 = "c_value2";
  status = _db->Put(_writeOptions, committed_key2, committed_value2);
  XCTAssertTrue(status.ok());

  LevelDBTransaction transaction(_db, _readOptions, _writeOptions);
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
    Status status =
        _db->Put(_writeOptions, "key_" + std::to_string(i), "value_" + std::to_string(i));
    XCTAssertTrue(status.ok());
  }
  LevelDBTransaction transaction(_db, _readOptions, _writeOptions);
  transaction.Put("key_1", "new_value");
  std::string value;
  Status status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, "new_value");

  transaction.Delete("key_1");
  status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.IsNotFound());

  LevelDBTransaction::Iterator iter(&transaction);
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
    Status status =
        _db->Put(_writeOptions, "key_" + std::to_string(i), "value_" + std::to_string(i));
    XCTAssertTrue(status.ok());
  }
  std::string value;
  LevelDBTransaction transaction(_db, _readOptions, _writeOptions);
  transaction.Delete("key_1");
  Status status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.IsNotFound());

  transaction.Put("key_1", "new_value");
  status = transaction.Get("key_1", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual(value, "new_value");

  transaction.Delete("key_3");

  LevelDBTransaction::Iterator iter(&transaction);
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

  status = _db->Get(_readOptions, "key_0", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual("value_0", value);

  status = _db->Get(_readOptions, "key_1", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual("new_value", value);

  status = _db->Get(_readOptions, "key_2", &value);
  XCTAssertTrue(status.ok());
  XCTAssertEqual("value_2", value);

  status = _db->Get(_readOptions, "key_3", &value);
  XCTAssertTrue(status.IsNotFound());
}

- (void)testProtobufSupport {
  LevelDBTransaction transaction(_db, _readOptions, _writeOptions);

  FSTPBTarget *target = [FSTPBTarget message];
  target.targetId = 1;
  target.lastListenSequenceNumber = 2;

  std::string key("theKey");
  transaction.Put(key, target);
  NSData *data = [target data];

  std::string value;
  Status status = transaction.Get("theKey", &value);
  NSData *result = [[NSData alloc] initWithBytesNoCopy:(void *)value.data() length:value.size() freeWhenDone:NO];
  NSError *error;
  FSTPBTarget *parsed = [FSTPBTarget parseFromData:result error:&error];
  XCTAssertNil(error);
  XCTAssertTrue([target isEqual:parsed]);
}


@end

NS_ASSUME_NONNULL_END
