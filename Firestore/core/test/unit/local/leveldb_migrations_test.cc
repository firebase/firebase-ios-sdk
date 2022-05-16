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

#include "Firestore/core/src/local/leveldb_migrations.h"

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/Protos/nanopb/firestore/local/mutation.nanopb.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_target_cache.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/util/ordered_code.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/match.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using leveldb::DB;
using leveldb::Options;
using leveldb::Status;
using model::BatchId;
using model::DocumentKey;
using model::ListenSequenceNumber;
using model::TargetId;
using nanopb::Message;
using testutil::Filter;
using testutil::Key;
using testutil::Query;
using util::OrderedCode;
using util::Path;

using SchemaVersion = LevelDbMigrations::SchemaVersion;

/**
 * Creates the name of a dummy entry to make sure the iteration is correctly
 * bounded.
 */
std::string DummyKey(const char* table_name) {
  std::string dummy_key;
  // Magic number that indicates a table name follows. Needed to mimic the
  // prefix to the target table.
  OrderedCode::WriteSignedNumIncreasing(&dummy_key, 5);
  OrderedCode::WriteString(&dummy_key, table_name);
  return dummy_key;
}

}  // namespace

class LevelDbMigrationsTest : public testing::Test {
 protected:
  void SetUp() override;

  std::unique_ptr<DB> db_ = nullptr;
  std::unique_ptr<LocalSerializer> serializer_ = nullptr;
};

void LevelDbMigrationsTest::SetUp() {
  Options options;
  options.error_if_exists = true;
  options.create_if_missing = true;

  Path dir = LevelDbDir();
  DB* db = nullptr;
  Status status = DB::Open(options, dir.ToUtf8String(), &db);
  ASSERT_TRUE(status.ok()) << "Failed to create db: "
                           << status.ToString().c_str();
  db_.reset(db);

  serializer_ = absl::make_unique<LocalSerializer>(MakeLocalSerializer());
}

TEST_F(LevelDbMigrationsTest, AddsTargetGlobal) {
  auto metadata = LevelDbTargetCache::TryReadMetadata(db_.get());
  ASSERT_TRUE(!metadata)
      << "Not expecting metadata yet, we should have an empty db";
  LevelDbMigrations::RunMigrations(db_.get(), *serializer_);

  metadata = LevelDbTargetCache::TryReadMetadata(db_.get());
  ASSERT_TRUE(metadata) << "Migrations should have added the metadata";
}

TEST_F(LevelDbMigrationsTest, SetsVersionNumber) {
  SchemaVersion initial = LevelDbMigrations::ReadSchemaVersion(db_.get());
  ASSERT_EQ(0, initial) << "No version should be equivalent to 0";

  // Pick an arbitrary high migration number and migrate to it.
  LevelDbMigrations::RunMigrations(db_.get(), *serializer_);

  SchemaVersion actual = LevelDbMigrations::ReadSchemaVersion(db_.get());
  ASSERT_GT(actual, 0) << "Expected to migrate to a schema version > 0";
}

MATCHER_P(IsFound, transaction, "") {
  std::string unused_result;
  Status status = transaction->Get(arg, &unused_result);
  return status.ok();
}

MATCHER_P(IsNotFound, transaction, "") {
  std::string unused_result;
  Status status = transaction->Get(arg, &unused_result);
  return status.IsNotFound();
}

TEST_F(LevelDbMigrationsTest, DropsTheTargetCache) {
  std::string user_id{"user"};
  BatchId batch_id = 1;
  TargetId target_id = 2;

  DocumentKey key1 = Key("documents/1");
  DocumentKey key2 = Key("documents/2");

  std::string target_keys[] = {
      LevelDbTargetKey::Key(target_id),
      LevelDbTargetDocumentKey::Key(target_id, key1),
      LevelDbTargetDocumentKey::Key(target_id, key2),
      LevelDbDocumentTargetKey::Key(key1, target_id),
      LevelDbDocumentTargetKey::Key(key2, target_id),
      LevelDbQueryTargetKey::Key("foo.bar.baz", target_id),
  };

  // Keys that should not be modified by the dropping the target cache
  std::string preserved_keys[] = {
      DummyKey("target_a"),
      LevelDbMutationQueueKey::Key(user_id),
      LevelDbMutationKey::Key(user_id, batch_id),
  };

  LevelDbMigrations::RunMigrations(db_.get(), 2, *serializer_);
  {
    // Setup some targets to be counted in the migration.
    LevelDbTransaction transaction(db_.get(),
                                   "test_drops_the_target_cache setup");
    for (const std::string& key : target_keys) {
      transaction.Put(key, "target");
    }
    for (const std::string& key : preserved_keys) {
      transaction.Put(key, "preserved");
    }
    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(db_.get(), 3, *serializer_);
  {
    LevelDbTransaction transaction(db_.get(), "test_drops_the_target_cache");
    for (const std::string& key : target_keys) {
      ASSERT_THAT(key, IsNotFound(&transaction));
    }
    for (const std::string& key : preserved_keys) {
      ASSERT_THAT(key, IsFound(&transaction));
    }

    auto metadata = LevelDbTargetCache::TryReadMetadata(db_.get());
    ASSERT_TRUE(metadata) << "Metadata should have been added";
    ASSERT_EQ(metadata.value()->target_count, 0);
  }
}

TEST_F(LevelDbMigrationsTest, DropsTheTargetCacheWithThousandsOfEntries) {
  LevelDbMigrations::RunMigrations(db_.get(), 2, *serializer_);
  {
    // Setup some targets to be destroyed.
    LevelDbTransaction transaction(
        db_.get(),
        "test_drops_the_target_cache_with_thousands_of_entries setup");
    for (int i = 0; i < 10000; ++i) {
      transaction.Put(LevelDbTargetKey::Key(i), "");
    }
    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(db_.get(), 3, *serializer_);
  {
    LevelDbTransaction transaction(db_.get(), "Verify");
    std::string prefix = LevelDbTargetKey::KeyPrefix();

    auto it = transaction.NewIterator();
    std::vector<std::string> found_keys;
    for (it->Seek(prefix); it->Valid() && absl::StartsWith(it->key(), prefix);
         it->Next()) {
      found_keys.push_back(std::string{it->key()});
    }

    ASSERT_EQ(found_keys, std::vector<std::string>{});
  }
}

TEST_F(LevelDbMigrationsTest, AddsSentinelRows) {
  ListenSequenceNumber old_sequence_number = 1;
  ListenSequenceNumber new_sequence_number = 2;
  std::string encoded_old_sequence_number =
      LevelDbDocumentTargetKey::EncodeSentinelValue(old_sequence_number);
  LevelDbMigrations::RunMigrations(db_.get(), 3, *serializer_);
  {
    std::string empty_buffer;
    LevelDbTransaction transaction(db_.get(), "Setup");

    // Set up target global
    auto metadata = LevelDbTargetCache::ReadMetadata(db_.get());
    // Expect that documents missing a row will get the new number
    metadata->highest_listen_sequence_number = new_sequence_number;
    transaction.Put(LevelDbTargetGlobalKey::Key(), metadata);

    // Set up some documents (we only need the keys)
    // For the odd ones, add sentinel rows.
    for (int i = 0; i < 10; i++) {
      DocumentKey key = DocumentKey::FromSegments({"docs", std::to_string(i)});
      transaction.Put(LevelDbRemoteDocumentKey::Key(key), empty_buffer);
      if (i % 2 == 1) {
        std::string sentinel_key = LevelDbDocumentTargetKey::SentinelKey(key);
        transaction.Put(sentinel_key, encoded_old_sequence_number);
      }
    }

    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(db_.get(), 4, *serializer_);
  {
    LevelDbTransaction transaction(db_.get(), "Verify");
    auto it = transaction.NewIterator();
    std::string documents_prefix = LevelDbRemoteDocumentKey::KeyPrefix();
    it->Seek(documents_prefix);
    int count = 0;
    LevelDbRemoteDocumentKey document_key;
    std::string buffer;
    for (; it->Valid() && absl::StartsWith(it->key(), documents_prefix);
         it->Next()) {
      count++;
      ASSERT_TRUE(document_key.Decode(it->key()));
      const DocumentKey& key = document_key.document_key();
      std::string sentinel_key = LevelDbDocumentTargetKey::SentinelKey(key);
      ASSERT_TRUE(transaction.Get(sentinel_key, &buffer).ok());
      int doc_number = atoi(key.path().last_segment().c_str());
      // If the document number is odd, we expect the original old sequence
      // number that we wrote. If it's even, we expect that the migration added
      // the new sequence number from the target global
      ListenSequenceNumber expected_sequence_number =
          doc_number % 2 == 1 ? old_sequence_number : new_sequence_number;
      ListenSequenceNumber sequence_number =
          LevelDbDocumentTargetKey::DecodeSentinelValue(buffer);
      ASSERT_EQ(expected_sequence_number, sequence_number);
    }
    ASSERT_EQ(10, count);
  }
}

TEST_F(LevelDbMigrationsTest, RemovesMutationBatches) {
  std::string empty_buffer;
  DocumentKey test_write_foo = DocumentKey::FromPathString("docs/foo");
  DocumentKey test_write_bar = DocumentKey::FromPathString("docs/bar");
  DocumentKey test_write_baz = DocumentKey::FromPathString("docs/baz");
  DocumentKey test_write_pending = DocumentKey::FromPathString("docs/pending");
  // Do everything up until the mutation batch migration.
  LevelDbMigrations::RunMigrations(db_.get(), 3, *serializer_);
  // Set up data
  {
    LevelDbTransaction transaction(db_.get(), "Setup Foo");
    // User 'foo' has two acknowledged mutations and one that is pending.
    Message<firestore_client_MutationQueue> foo_queue;
    foo_queue->last_acknowledged_batch_id = 2;
    std::string foo_key = LevelDbMutationQueueKey::Key("foo");
    transaction.Put(foo_key, foo_queue);

    Message<firestore_client_WriteBatch> foo_batch1;
    foo_batch1->batch_id = 1;
    std::string foo_batch_key1 = LevelDbMutationKey::Key("foo", 1);
    transaction.Put(foo_batch_key1, foo_batch1);
    transaction.Put(LevelDbDocumentMutationKey::Key("foo", test_write_foo, 1),
                    empty_buffer);

    Message<firestore_client_WriteBatch> foo_batch2;
    foo_batch2->batch_id = 2;
    std::string foo_batch_key2 = LevelDbMutationKey::Key("foo", 2);
    transaction.Put(foo_batch_key2, foo_batch2);
    transaction.Put(LevelDbDocumentMutationKey::Key("foo", test_write_foo, 2),
                    empty_buffer);

    Message<firestore_client_WriteBatch> foo_batch3;
    foo_batch3->batch_id = 5;
    std::string foo_batch_key3 = LevelDbMutationKey::Key("foo", 5);
    transaction.Put(foo_batch_key3, foo_batch3);
    transaction.Put(
        LevelDbDocumentMutationKey::Key("foo", test_write_pending, 5),
        empty_buffer);

    transaction.Commit();
  }

  {
    LevelDbTransaction transaction(db_.get(), "Setup Bar");
    // User 'bar' has one acknowledged mutation and one that is pending
    Message<firestore_client_MutationQueue> bar_queue;
    bar_queue->last_acknowledged_batch_id = 3;
    std::string bar_key = LevelDbMutationQueueKey::Key("bar");
    transaction.Put(bar_key, bar_queue);

    Message<firestore_client_WriteBatch> bar_batch1;
    bar_batch1->batch_id = 3;
    std::string bar_batch_key1 = LevelDbMutationKey::Key("bar", 3);
    transaction.Put(bar_batch_key1, bar_batch1);
    transaction.Put(LevelDbDocumentMutationKey::Key("bar", test_write_bar, 3),
                    empty_buffer);
    transaction.Put(LevelDbDocumentMutationKey::Key("bar", test_write_baz, 3),
                    empty_buffer);

    Message<firestore_client_WriteBatch> bar_batch2;
    bar_batch2->batch_id = 4;
    std::string bar_batch_key2 = LevelDbMutationKey::Key("bar", 4);
    transaction.Put(bar_batch_key2, bar_batch2);
    transaction.Put(
        LevelDbDocumentMutationKey::Key("bar", test_write_pending, 4),
        empty_buffer);

    transaction.Commit();
  }

  {
    LevelDbTransaction transaction(db_.get(), "Setup Empty");
    // User 'empty' has no mutations
    Message<firestore_client_MutationQueue> empty_queue;
    empty_queue->last_acknowledged_batch_id = -1;
    std::string empty_key = LevelDbMutationQueueKey::Key("empty");
    transaction.Put(empty_key, empty_queue);
    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(db_.get(), 5, *serializer_);

  {
    // Verify
    std::string buffer;
    LevelDbTransaction transaction(db_.get(), "Verify");
    // verify that we deleted the correct batches
    ASSERT_TRUE(transaction.Get(LevelDbMutationKey::Key("foo", 1), &buffer)
                    .IsNotFound());
    ASSERT_TRUE(transaction.Get(LevelDbMutationKey::Key("foo", 2), &buffer)
                    .IsNotFound());
    ASSERT_TRUE(
        transaction.Get(LevelDbMutationKey::Key("foo", 5), &buffer).ok());

    ASSERT_TRUE(transaction.Get(LevelDbMutationKey::Key("bar", 3), &buffer)
                    .IsNotFound());
    ASSERT_TRUE(
        transaction.Get(LevelDbMutationKey::Key("bar", 4), &buffer).ok());

    // verify document associations have been removed
    ASSERT_TRUE(
        transaction
            .Get(LevelDbDocumentMutationKey::Key("foo", test_write_foo, 1),
                 &buffer)
            .IsNotFound());
    ASSERT_TRUE(
        transaction
            .Get(LevelDbDocumentMutationKey::Key("foo", test_write_foo, 2),
                 &buffer)
            .IsNotFound());
    ASSERT_TRUE(
        transaction
            .Get(LevelDbDocumentMutationKey::Key("foo", test_write_pending, 5),
                 &buffer)
            .ok());

    ASSERT_TRUE(
        transaction
            .Get(LevelDbDocumentMutationKey::Key("bar", test_write_bar, 3),
                 &buffer)
            .IsNotFound());
    ASSERT_TRUE(
        transaction
            .Get(LevelDbDocumentMutationKey::Key("bar", test_write_baz, 3),
                 &buffer)
            .IsNotFound());
    ASSERT_TRUE(
        transaction
            .Get(LevelDbDocumentMutationKey::Key("bar", test_write_pending, 4),
                 &buffer)
            .ok());
  }
}

TEST_F(LevelDbMigrationsTest, CreateCollectionParentsIndex) {
  // This test creates a database with schema version 5 that has a few
  // mutations and a few remote documents and then ensures that appropriate
  // entries are written to the collection_parent_index.
  std::vector<std::string> write_paths{"cg1/x", "cg1/y", "cg1/x/cg1/x", "cg2/x",
                                       "cg1/x/cg2/x"};
  std::vector<std::string> remote_doc_paths{
      "cg1/z", "cg1/y/cg1/x", "cg2/x/cg3/x", "blah/x/blah/x/cg3/x"};
  std::map<std::string, std::vector<std::string>> expected_parents{
      {"cg1", {"", "cg1/x", "cg1/y"}},
      {"cg2", {"", "cg1/x"}},
      {"cg3", {"blah/x/blah/x", "cg2/x"}}};

  std::string empty_buffer;
  LevelDbMigrations::RunMigrations(db_.get(), 5, *serializer_);
  {
    LevelDbTransaction transaction(db_.get(),
                                   "Write Mutations and Remote Documents");
    // Write mutations.
    for (auto write_path : write_paths) {
      // We "cheat" and only write the DbDocumentMutation index entries, since
      // that's all the migration uses.
      DocumentKey key = DocumentKey::FromPathString(write_path);
      transaction.Put(LevelDbDocumentMutationKey::Key("dummy-uid", key,
                                                      /*dummy batch_id=*/123),
                      empty_buffer);
    }

    // Write remote document entries.
    for (auto remote_doc_path : remote_doc_paths) {
      DocumentKey key = DocumentKey::FromPathString(remote_doc_path);
      transaction.Put(LevelDbRemoteDocumentKey::Key(key), empty_buffer);
    }

    transaction.Commit();
  }

  // Migrate to v6 and verify index entries.
  LevelDbMigrations::RunMigrations(db_.get(), 6, *serializer_);
  {
    LevelDbTransaction transaction(db_.get(), "Verify");

    std::map<std::string, std::vector<std::string>> actual_parents;
    auto index_iterator = transaction.NewIterator();
    std::string index_prefix = LevelDbCollectionParentKey::KeyPrefix();
    LevelDbCollectionParentKey row_key;
    for (index_iterator->Seek(index_prefix); index_iterator->Valid();
         index_iterator->Next()) {
      if (!absl::StartsWith(index_iterator->key(), index_prefix) ||
          !row_key.Decode(index_iterator->key()))
        break;

      std::vector<std::string>& parents =
          actual_parents[row_key.collection_id()];
      parents.push_back(row_key.parent().CanonicalString());
    }

    ASSERT_EQ(actual_parents, expected_parents);
  }
}

TEST_F(LevelDbMigrationsTest, RewritesCanonicalIds) {
  LevelDbMigrations::RunMigrations(db_.get(), 6, *serializer_);
  auto query = Query("collection").AddingFilter(Filter("foo", "==", "bar"));
  TargetData initial_target_data(query.ToTarget(),
                                 /* target_id= */ 2,
                                 /* sequence_number= */ 1,
                                 QueryPurpose::Listen);
  auto invalid_key = LevelDbQueryTargetKey::Key(
      "invalid_canonical_id", initial_target_data.target_id());

  // Write the target with invalid canonical id into leveldb.
  {
    LevelDbTransaction transaction(db_.get(),
                                   "Write target with invalid canonical ID");
    auto target_key = LevelDbTargetKey::Key(2);
    transaction.Put(target_key,
                    serializer_->EncodeTargetData(initial_target_data));

    std::string empty_buffer;
    transaction.Put(invalid_key, empty_buffer);

    transaction.Commit();
  }

  // Run migration and verify canonical id is rewritten with valid string.
  {
    LevelDbMigrations::RunMigrations(db_.get(), *serializer_);

    LevelDbTransaction transaction(
        db_.get(), "Read target to verify canonical ID rewritten");

    auto query_target_key =
        LevelDbQueryTargetKey::Key(initial_target_data.target().CanonicalId(),
                                   initial_target_data.target_id());
    auto it = transaction.NewIterator();
    // Verify we are able to seek to the key built with proper canonical ID.
    it->Seek(query_target_key);
    ASSERT_EQ(it->key(), query_target_key);

    // Verify original invalid key is deleted.
    it->Seek(invalid_key);
    ASSERT_NE(it->key(), invalid_key);
    transaction.Commit();
  }
}

TEST_F(LevelDbMigrationsTest, CanDowngrade) {
  // First, run all of the migrations
  LevelDbMigrations::RunMigrations(db_.get(), *serializer_);

  LevelDbMigrations::SchemaVersion latest_version =
      LevelDbMigrations::ReadSchemaVersion(db_.get());

  // Downgrade to an early version.
  LevelDbMigrations::SchemaVersion downgrade_version = 1;
  LevelDbMigrations::RunMigrations(db_.get(), downgrade_version, *serializer_);
  LevelDbMigrations::SchemaVersion post_downgrade_version =
      LevelDbMigrations::ReadSchemaVersion(db_.get());
  ASSERT_EQ(downgrade_version, post_downgrade_version);

  // Verify that we can upgrade again to the latest version.
  LevelDbMigrations::RunMigrations(db_.get(), *serializer_);
  LevelDbMigrations::SchemaVersion final_version =
      LevelDbMigrations::ReadSchemaVersion(db_.get());
  ASSERT_EQ(final_version, latest_version);
}

TEST_F(LevelDbMigrationsTest, SetsOverlayMigrationFlag) {
  LevelDbMigrations::RunMigrations(db_.get(), *serializer_);

  LevelDbMigrations::SchemaVersion schema_version =
      LevelDbMigrations::ReadSchemaVersion(db_.get());
  ASSERT_GE(schema_version, 8);

  LevelDbTransaction transaction(db_.get(), "Read migration flag");
  std::string key = LevelDbDataMigrationKey::OverlayMigrationKey();
  std::string flag;
  Status status = transaction.Get(key, &flag);
  ASSERT_TRUE(status.ok());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
