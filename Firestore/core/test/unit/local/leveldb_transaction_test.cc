/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/local/leveldb_transaction.h"

#include <memory>
#include <string>

#include "Firestore/Protos/nanopb/firestore/local/mutation.nanopb.h"
#include "Firestore/Protos/nanopb/firestore/local/target.nanopb.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "absl/strings/string_view.h"
#include "gtest/gtest.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {

using leveldb::DB;
using leveldb::Options;
using leveldb::ReadOptions;
using leveldb::Status;
using leveldb::WriteOptions;
using nanopb::ByteString;
using nanopb::Message;
using nanopb::StringReader;
using util::Path;

class LevelDbTransactionTest : public testing::Test {
 protected:
  void SetUp() override;

  std::unique_ptr<DB> db_;
};

void LevelDbTransactionTest::SetUp() {
  Options options;
  options.error_if_exists = true;
  options.create_if_missing = true;

  Path dir = LevelDbDir();
  DB* db = nullptr;
  Status status = DB::Open(options, dir.ToUtf8String(), &db);
  ASSERT_TRUE(status.ok()) << "Failed to create db: "
                           << status.ToString().c_str();
  db_.reset(db);
}

TEST_F(LevelDbTransactionTest, CreateTransaction) {
  LevelDbTransaction transaction(db_.get(), "CreateTransaction");
  std::string key = "key1";

  transaction.Put(key, "value");
  auto iter = transaction.NewIterator();
  iter->Seek(key);
  ASSERT_EQ(key, iter->key());
  iter->Next();
  ASSERT_FALSE(iter->Valid());
}

TEST_F(LevelDbTransactionTest, CanReadCommittedAndMutations) {
  const std::string committed_key1 = "c_key1";
  const std::string committed_value1 = "c_value1";
  const WriteOptions& write_options = LevelDbTransaction::DefaultWriteOptions();
  // add two things committed, mutate one, add another mutation
  // verify you can get the original committed, the mutation, and the addition
  Status status = db_->Put(write_options, committed_key1, committed_value1);
  ASSERT_TRUE(status.ok());

  const std::string committed_key2 = "c_key2";
  const std::string committed_value2 = "c_value2";
  status = db_->Put(write_options, committed_key2, committed_value2);
  ASSERT_TRUE(status.ok());

  LevelDbTransaction transaction(db_.get(), "CanReadCommittedAndMutations");
  const std::string mutation_key1 = "m_key1";
  const std::string mutation_value1 = "m_value1";
  transaction.Put(mutation_key1, mutation_value1);

  const std::string mutation_key2 = committed_key2;
  const std::string mutation_value2 = "m_value2";
  transaction.Put(mutation_key2, mutation_value2);

  std::string value;
  status = transaction.Get(committed_key1, &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ(value, committed_value1);

  status = transaction.Get(mutation_key1, &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ(value, mutation_value1);

  status = transaction.Get(committed_key2, &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ(value, mutation_value2);
}

TEST_F(LevelDbTransactionTest, DeleteCommitted) {
  // add something committed, delete it, verify you can't read it
  for (int i = 0; i < 3; ++i) {
    Status status =
        db_->Put(LevelDbTransaction::DefaultWriteOptions(),
                 "key_" + std::to_string(i), "value_" + std::to_string(i));
    ASSERT_TRUE(status.ok());
  }
  LevelDbTransaction transaction(db_.get(), "DeleteCommitted");
  transaction.Put("key_1", "new_value");
  std::string value;
  Status status = transaction.Get("key_1", &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ(value, "new_value");

  transaction.Delete("key_1");
  status = transaction.Get("key_1", &value);
  ASSERT_TRUE(status.IsNotFound());

  LevelDbTransaction::Iterator iter(&transaction);
  iter.Seek("");
  ASSERT_EQ(iter.key(), "key_0");
  iter.Next();
  ASSERT_EQ(iter.key(), "key_2");
  iter.Next();
  ASSERT_FALSE(iter.Valid());
}

TEST_F(LevelDbTransactionTest, MutateDeleted) {
  // delete something, then mutate it, then read it.
  // Also include an actual deletion
  for (int i = 0; i < 4; ++i) {
    Status status =
        db_->Put(LevelDbTransaction::DefaultWriteOptions(),
                 "key_" + std::to_string(i), "value_" + std::to_string(i));
    ASSERT_TRUE(status.ok());
  }
  std::string value;
  LevelDbTransaction transaction(db_.get(), "MutateDeleted");
  transaction.Delete("key_1");
  Status status = transaction.Get("key_1", &value);
  ASSERT_TRUE(status.IsNotFound());

  transaction.Put("key_1", "new_value");
  status = transaction.Get("key_1", &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ(value, "new_value");

  transaction.Delete("key_3");

  LevelDbTransaction::Iterator iter(&transaction);
  iter.Seek("");
  ASSERT_EQ(iter.key(), "key_0");
  iter.Next();
  ASSERT_EQ(iter.key(), "key_1");
  ASSERT_EQ(iter.value(), "new_value");
  iter.Next();
  ASSERT_EQ(iter.key(), "key_2");
  iter.Next();
  ASSERT_FALSE(iter.Valid());

  // Commit, then check underlying db.
  transaction.Commit();

  const ReadOptions& read_options = LevelDbTransaction::DefaultReadOptions();
  status = db_->Get(read_options, "key_0", &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ("value_0", value);

  status = db_->Get(read_options, "key_1", &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ("new_value", value);

  status = db_->Get(read_options, "key_2", &value);
  ASSERT_TRUE(status.ok());
  ASSERT_EQ("value_2", value);

  status = db_->Get(read_options, "key_3", &value);
  ASSERT_TRUE(status.IsNotFound());
}

TEST_F(LevelDbTransactionTest, ProtobufSupport) {
  LevelDbTransaction transaction(db_.get(), "ProtobufSupport");

  Message<firestore_client_Target> target;
  target->target_id = 1;
  target->last_listen_sequence_number = 2;

  std::string key("the_key");
  transaction.Put(key, target);

  std::string value;
  Status status = transaction.Get("the_key", &value);

  ByteString bytes{value};
  StringReader reader{bytes};
  auto parsed = Message<firestore_client_Target>::TryParse(&reader);
  ASSERT_TRUE(reader.ok());
  ASSERT_EQ(target->target_id, parsed->target_id);
  ASSERT_EQ(target->last_listen_sequence_number,
            parsed->last_listen_sequence_number);
}

TEST_F(LevelDbTransactionTest, CanIterateAndDelete) {
  LevelDbTransaction transaction(db_.get(), "CanIterateAndDelete");

  for (int i = 0; i < 4; ++i) {
    transaction.Put("key_" + std::to_string(i), "value_" + std::to_string(i));
  }

  auto it = transaction.NewIterator();
  it->Seek("key_0");
  for (int i = 0; i < 4; ++i) {
    ASSERT_TRUE(it->Valid());
    absl::string_view key = it->key();
    std::string expected = "key_" + std::to_string(i);
    ASSERT_EQ(expected, key);
    transaction.Delete(key);
    it->Next();
  }
}

TEST_F(LevelDbTransactionTest, CanIterateFromDeletionToCommitted) {
  // Write keys key_0 and key_1
  for (int i = 0; i < 2; ++i) {
    Status status =
        db_->Put(LevelDbTransaction::DefaultWriteOptions(),
                 "key_" + std::to_string(i), "value_" + std::to_string(i));
    ASSERT_TRUE(status.ok());
  }

  // Create a transaction, iterate, deleting key_0. Verify we still iterate
  // key_1.
  LevelDbTransaction transaction(db_.get(),
                                 "CanIterateFromDeletionToCommitted");
  auto it = transaction.NewIterator();
  it->Seek("key_0");
  ASSERT_TRUE(it->Valid());
  ASSERT_EQ("key_0", it->key());
  transaction.Delete("key_0");
  it->Next();
  ASSERT_TRUE(it->Valid());
  ASSERT_EQ("key_1", it->key());
  it->Next();
  ASSERT_FALSE(it->Valid());
}

TEST_F(LevelDbTransactionTest, DeletingAheadOfAnIterator) {
  // Write keys
  for (int i = 0; i < 4; ++i) {
    Status status =
        db_->Put(LevelDbTransaction::DefaultWriteOptions(),
                 "key_" + std::to_string(i), "value_" + std::to_string(i));
    ASSERT_TRUE(status.ok());
  }

  // Create a transaction, iterate to key_1, delete key_2. Verify we still
  // iterate key_3.
  LevelDbTransaction transaction(db_.get(), "DeletingAheadOfAnIterator");
  auto it = transaction.NewIterator();
  it->Seek("key_0");
  ASSERT_TRUE(it->Valid());
  ASSERT_EQ("key_0", it->key());
  it->Next();
  ASSERT_TRUE(it->Valid());
  ASSERT_EQ("key_1", it->key());
  transaction.Delete("key_2");
  it->Next();
  ASSERT_TRUE(it->Valid());
  ASSERT_EQ("key_3", it->key());
  ASSERT_TRUE(it->Valid());
  it->Next();
  ASSERT_FALSE(it->Valid());
}

TEST_F(LevelDbTransactionTest, ToString) {
  std::string key = LevelDbMutationKey::Key("user1", 42);
  Message<firestore_client_WriteBatch> message;
  message->batch_id = 42;

  LevelDbTransaction transaction(db_.get(), "ToString");
  std::string description = transaction.ToString();
  ASSERT_EQ(description, "<LevelDbTransaction ToString: 0 changes (0 bytes):>");

  transaction.Put(key, message);
  description = transaction.ToString();
  ASSERT_EQ(description,
            "<LevelDbTransaction ToString: 1 changes (2 bytes):\n"
            "  - Put [mutation: user_id=user1 batch_id=42] (2 bytes)>");

  std::string key2 = LevelDbMutationKey::Key("user1", 43);
  transaction.Delete(key2);
  description = transaction.ToString();
  ASSERT_EQ(description,
            "<LevelDbTransaction ToString: 2 changes (2 bytes):\n"
            "  - Delete [mutation: user_id=user1 batch_id=43]\n"
            "  - Put [mutation: user_id=user1 batch_id=42] (2 bytes)>");
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
