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

#include <map>
#include <memory>
#include <string>
#include <vector>

#import "Firestore/Protos/objc/firestore/local/Mutation.pbobjc.h"
#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_migrations.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_query_cache.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/test/firebase/firestore/local/persistence_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/strings/match.h"
#include "leveldb/db.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::Error;
using firebase::firestore::nanopb::firestore_client_TargetGlobal;
using firebase::firestore::local::LevelDbCollectionParentKey;
using firebase::firestore::local::LevelDbDir;
using firebase::firestore::local::LevelDbDocumentMutationKey;
using firebase::firestore::local::LevelDbDocumentTargetKey;
using firebase::firestore::local::LevelDbMigrations;
using firebase::firestore::local::LevelDbMutationKey;
using firebase::firestore::local::LevelDbMutationQueueKey;
using firebase::firestore::local::LevelDbQueryCache;
using firebase::firestore::local::LevelDbQueryTargetKey;
using firebase::firestore::local::LevelDbRemoteDocumentKey;
using firebase::firestore::local::LevelDbTargetDocumentKey;
using firebase::firestore::local::LevelDbTargetGlobalKey;
using firebase::firestore::local::LevelDbTargetKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::TargetId;
using firebase::firestore::nanopb::Message;
using firebase::firestore::testutil::Key;
using firebase::firestore::util::OrderedCode;
using firebase::firestore::util::Path;
using leveldb::DB;
using leveldb::Options;
using leveldb::Status;

using SchemaVersion = LevelDbMigrations::SchemaVersion;

@interface FSTLevelDBMigrationsTests : XCTestCase
@end

@implementation FSTLevelDBMigrationsTests {
  std::unique_ptr<DB> _db;
}

- (void)setUp {
  Options options;
  options.error_if_exists = true;
  options.create_if_missing = true;

  Path dir = LevelDbDir();
  DB *db;
  Status status = DB::Open(options, dir.ToUtf8String(), &db);
  XCTAssert(status.ok(), @"Failed to create db: %s", status.ToString().c_str());
  _db.reset(db);
}

- (void)tearDown {
  _db.reset();
}

- (void)testAddsTargetGlobal {
  auto metadata = LevelDbQueryCache::TryReadMetadata(_db.get());
  XCTAssert(!metadata, @"Not expecting metadata yet, we should have an empty db");
  LevelDbMigrations::RunMigrations(_db.get());

  metadata = LevelDbQueryCache::TryReadMetadata(_db.get());
  XCTAssert(metadata, @"Migrations should have added the metadata");
}

- (void)testSetsVersionNumber {
  SchemaVersion initial = LevelDbMigrations::ReadSchemaVersion(_db.get());
  XCTAssertEqual(0, initial, "No version should be equivalent to 0");

  // Pick an arbitrary high migration number and migrate to it.
  LevelDbMigrations::RunMigrations(_db.get());

  SchemaVersion actual = LevelDbMigrations::ReadSchemaVersion(_db.get());
  XCTAssertGreaterThan(actual, 0, @"Expected to migrate to a schema version > 0");
}

#define ASSERT_NOT_FOUND(transaction, key)                \
  do {                                                    \
    std::string unused_result;                            \
    Status status = transaction.Get(key, &unused_result); \
    XCTAssertTrue(status.IsNotFound());                   \
  } while (0)

#define ASSERT_FOUND(transaction, key)                    \
  do {                                                    \
    std::string unused_result;                            \
    Status status = transaction.Get(key, &unused_result); \
    XCTAssertTrue(status.ok());                           \
  } while (0)

- (void)testDropsTheQueryCache {
  std::string userID{"user"};
  BatchId batchID = 1;
  TargetId targetID = 2;

  DocumentKey key1 = Key("documents/1");
  DocumentKey key2 = Key("documents/2");

  std::string targetKeys[] = {
      LevelDbTargetKey::Key(targetID),
      LevelDbTargetDocumentKey::Key(targetID, key1),
      LevelDbTargetDocumentKey::Key(targetID, key2),
      LevelDbDocumentTargetKey::Key(key1, targetID),
      LevelDbDocumentTargetKey::Key(key2, targetID),
      LevelDbQueryTargetKey::Key("foo.bar.baz", targetID),
  };

  // Keys that should not be modified by the dropping the query cache
  std::string preservedKeys[] = {
      [self dummyKeyForTable:"targetA"],
      LevelDbMutationQueueKey::Key(userID),
      LevelDbMutationKey::Key(userID, batchID),
  };

  LevelDbMigrations::RunMigrations(_db.get(), 2);
  {
    // Setup some targets to be counted in the migration.
    LevelDbTransaction transaction(_db.get(), "testDropsTheQueryCache setup");
    for (const std::string &key : targetKeys) {
      transaction.Put(key, "target");
    }
    for (const std::string &key : preservedKeys) {
      transaction.Put(key, "preserved");
    }
    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(_db.get(), 3);
  {
    LevelDbTransaction transaction(_db.get(), "testDropsTheQueryCache");
    for (const std::string &key : targetKeys) {
      ASSERT_NOT_FOUND(transaction, key);
    }
    for (const std::string &key : preservedKeys) {
      ASSERT_FOUND(transaction, key);
    }

    auto metadata = LevelDbQueryCache::TryReadMetadata(_db.get());
    XCTAssert(metadata, @"Metadata should have been added");
    XCTAssertEqual(metadata.value()->target_count, 0);
  }
}

- (void)testDropsTheQueryCacheWithThousandsOfEntries {
  LevelDbMigrations::RunMigrations(_db.get(), 2);
  {
    // Setup some targets to be destroyed.
    LevelDbTransaction transaction(_db.get(), "testDropsTheQueryCacheWithThousandsOfEntries setup");
    for (int i = 0; i < 10000; ++i) {
      transaction.Put(LevelDbTargetKey::Key(i), "");
    }
    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(_db.get(), 3);
  {
    LevelDbTransaction transaction(_db.get(), "Verify");
    std::string prefix = LevelDbTargetKey::KeyPrefix();

    auto it = transaction.NewIterator();
    std::vector<std::string> found_keys;
    for (it->Seek(prefix); it->Valid() && absl::StartsWith(it->key(), prefix); it->Next()) {
      found_keys.push_back(std::string{it->key()});
    }

    XCTAssertEqual(found_keys, std::vector<std::string>{});
  }
}

- (void)testAddsSentinelRows {
  ListenSequenceNumber old_sequence_number = 1;
  ListenSequenceNumber new_sequence_number = 2;
  std::string encoded_old_sequence_number =
      LevelDbDocumentTargetKey::EncodeSentinelValue(old_sequence_number);
  LevelDbMigrations::RunMigrations(_db.get(), 3);
  {
    std::string empty_buffer;
    LevelDbTransaction transaction(_db.get(), "Setup");

    // Set up target global
    auto metadata = LevelDbQueryCache::ReadMetadata(_db.get());
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

  LevelDbMigrations::RunMigrations(_db.get(), 4);
  {
    LevelDbTransaction transaction(_db.get(), "Verify");
    auto it = transaction.NewIterator();
    std::string documents_prefix = LevelDbRemoteDocumentKey::KeyPrefix();
    it->Seek(documents_prefix);
    int count = 0;
    LevelDbRemoteDocumentKey document_key;
    std::string buffer;
    for (; it->Valid() && absl::StartsWith(it->key(), documents_prefix); it->Next()) {
      count++;
      XCTAssertTrue(document_key.Decode(it->key()));
      const DocumentKey &key = document_key.document_key();
      std::string sentinel_key = LevelDbDocumentTargetKey::SentinelKey(key);
      XCTAssertTrue(transaction.Get(sentinel_key, &buffer).ok());
      int doc_number = atoi(key.path().last_segment().c_str());
      // If the document number is odd, we expect the original old sequence number that we wrote.
      // If it's even, we expect that the migration added the new sequence number from the target
      // global
      ListenSequenceNumber expected_sequence_number =
          doc_number % 2 == 1 ? old_sequence_number : new_sequence_number;
      ListenSequenceNumber sequence_number = LevelDbDocumentTargetKey::DecodeSentinelValue(buffer);
      XCTAssertEqual(expected_sequence_number, sequence_number);
    }
    XCTAssertEqual(10, count);
  }
}

- (void)testRemovesMutationBatches {
  std::string emptyBuffer;
  DocumentKey testWriteFoo = DocumentKey::FromPathString("docs/foo");
  DocumentKey testWriteBar = DocumentKey::FromPathString("docs/bar");
  DocumentKey testWriteBaz = DocumentKey::FromPathString("docs/baz");
  DocumentKey testWritePending = DocumentKey::FromPathString("docs/pending");
  // Do everything up until the mutation batch migration.
  LevelDbMigrations::RunMigrations(_db.get(), 3);
  // Set up data
  {
    LevelDbTransaction transaction(_db.get(), "Setup Foo");
    // User 'foo' has two acknowledged mutations and one that is pending.
    FSTPBMutationQueue *fooQueue = [[FSTPBMutationQueue alloc] init];
    fooQueue.lastAcknowledgedBatchId = 2;
    std::string fooKey = LevelDbMutationQueueKey::Key("foo");
    transaction.Put(fooKey, fooQueue);

    FSTPBWriteBatch *fooBatch1 = [[FSTPBWriteBatch alloc] init];
    fooBatch1.batchId = 1;
    std::string fooBatchKey1 = LevelDbMutationKey::Key("foo", 1);
    transaction.Put(fooBatchKey1, fooBatch1);
    transaction.Put(LevelDbDocumentMutationKey::Key("foo", testWriteFoo, 1), emptyBuffer);

    FSTPBWriteBatch *fooBatch2 = [[FSTPBWriteBatch alloc] init];
    fooBatch2.batchId = 2;
    std::string fooBatchKey2 = LevelDbMutationKey::Key("foo", 2);
    transaction.Put(fooBatchKey2, fooBatch2);
    transaction.Put(LevelDbDocumentMutationKey::Key("foo", testWriteFoo, 2), emptyBuffer);

    FSTPBWriteBatch *fooBatch3 = [[FSTPBWriteBatch alloc] init];
    fooBatch3.batchId = 5;
    std::string fooBatchKey3 = LevelDbMutationKey::Key("foo", 5);
    transaction.Put(fooBatchKey3, fooBatch3);
    transaction.Put(LevelDbDocumentMutationKey::Key("foo", testWritePending, 5), emptyBuffer);

    transaction.Commit();
  }

  {
    LevelDbTransaction transaction(_db.get(), "Setup Bar");
    // User 'bar' has one acknowledged mutation and one that is pending
    FSTPBMutationQueue *barQueue = [[FSTPBMutationQueue alloc] init];
    barQueue.lastAcknowledgedBatchId = 3;
    std::string barKey = LevelDbMutationQueueKey::Key("bar");
    transaction.Put(barKey, barQueue);

    FSTPBWriteBatch *barBatch1 = [[FSTPBWriteBatch alloc] init];
    barBatch1.batchId = 3;
    std::string barBatchKey1 = LevelDbMutationKey::Key("bar", 3);
    transaction.Put(barBatchKey1, barBatch1);
    transaction.Put(LevelDbDocumentMutationKey::Key("bar", testWriteBar, 3), emptyBuffer);
    transaction.Put(LevelDbDocumentMutationKey::Key("bar", testWriteBaz, 3), emptyBuffer);

    FSTPBWriteBatch *barBatch2 = [[FSTPBWriteBatch alloc] init];
    barBatch2.batchId = 4;
    std::string barBatchKey2 = LevelDbMutationKey::Key("bar", 4);
    transaction.Put(barBatchKey2, barBatch2);
    transaction.Put(LevelDbDocumentMutationKey::Key("bar", testWritePending, 4), emptyBuffer);

    transaction.Commit();
  }

  {
    LevelDbTransaction transaction(_db.get(), "Setup Empty");
    // User 'empty' has no mutations
    FSTPBMutationQueue *emptyQueue = [[FSTPBMutationQueue alloc] init];
    emptyQueue.lastAcknowledgedBatchId = -1;
    std::string emptyKey = LevelDbMutationQueueKey::Key("empty");
    transaction.Put(emptyKey, emptyQueue);
    transaction.Commit();
  }

  LevelDbMigrations::RunMigrations(_db.get(), 5);

  {
    // Verify
    std::string buffer;
    LevelDbTransaction transaction(_db.get(), "Verify");
    // verify that we deleted the correct batches
    XCTAssertTrue(transaction.Get(LevelDbMutationKey::Key("foo", 1), &buffer).IsNotFound());
    XCTAssertTrue(transaction.Get(LevelDbMutationKey::Key("foo", 2), &buffer).IsNotFound());
    XCTAssertTrue(transaction.Get(LevelDbMutationKey::Key("foo", 5), &buffer).ok());

    XCTAssertTrue(transaction.Get(LevelDbMutationKey::Key("bar", 3), &buffer).IsNotFound());
    XCTAssertTrue(transaction.Get(LevelDbMutationKey::Key("bar", 4), &buffer).ok());

    // verify document associations have been removed
    XCTAssertTrue(transaction.Get(LevelDbDocumentMutationKey::Key("foo", testWriteFoo, 1), &buffer)
                      .IsNotFound());
    XCTAssertTrue(transaction.Get(LevelDbDocumentMutationKey::Key("foo", testWriteFoo, 2), &buffer)
                      .IsNotFound());
    XCTAssertTrue(
        transaction.Get(LevelDbDocumentMutationKey::Key("foo", testWritePending, 5), &buffer).ok());

    XCTAssertTrue(transaction.Get(LevelDbDocumentMutationKey::Key("bar", testWriteBar, 3), &buffer)
                      .IsNotFound());
    XCTAssertTrue(transaction.Get(LevelDbDocumentMutationKey::Key("bar", testWriteBaz, 3), &buffer)
                      .IsNotFound());
    XCTAssertTrue(
        transaction.Get(LevelDbDocumentMutationKey::Key("bar", testWritePending, 4), &buffer).ok());
  }
}

- (void)testCreateCollectionParentsIndex {
  // This test creates a database with schema version 5 that has a few
  // mutations and a few remote documents and then ensures that appropriate
  // entries are written to the collectionParentIndex.
  std::vector<std::string> write_paths{"cg1/x", "cg1/y", "cg1/x/cg1/x", "cg2/x", "cg1/x/cg2/x"};
  std::vector<std::string> remote_doc_paths{"cg1/z", "cg1/y/cg1/x", "cg2/x/cg3/x",
                                            "blah/x/blah/x/cg3/x"};
  std::map<std::string, std::vector<std::string>> expected_parents{
      {"cg1", {"", "cg1/x", "cg1/y"}}, {"cg2", {"", "cg1/x"}}, {"cg3", {"blah/x/blah/x", "cg2/x"}}};

  std::string empty_buffer;
  LevelDbMigrations::RunMigrations(_db.get(), 5);
  {
    LevelDbTransaction transaction(_db.get(), "Write Mutations and Remote Documents");
    // Write mutations.
    for (auto write_path : write_paths) {
      // We "cheat" and only write the DbDocumentMutation index entries, since
      // that's all the migration uses.
      DocumentKey key = DocumentKey::FromPathString(write_path);
      transaction.Put(LevelDbDocumentMutationKey::Key("dummy-uid", key, /*dummy batchId=*/123),
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
  LevelDbMigrations::RunMigrations(_db.get(), 6);
  {
    LevelDbTransaction transaction(_db.get(), "Verify");

    std::map<std::string, std::vector<std::string>> actual_parents;
    auto index_iterator = transaction.NewIterator();
    std::string index_prefix = LevelDbCollectionParentKey::KeyPrefix();
    LevelDbCollectionParentKey row_key;
    for (index_iterator->Seek(index_prefix); index_iterator->Valid(); index_iterator->Next()) {
      if (!absl::StartsWith(index_iterator->key(), index_prefix) ||
          !row_key.Decode(index_iterator->key()))
        break;

      std::vector<std::string> &parents = actual_parents[row_key.collection_id()];
      parents.push_back(row_key.parent().CanonicalString());
    }

    XCTAssertEqual(actual_parents, expected_parents);
  }
}

- (void)testCanDowngrade {
  // First, run all of the migrations
  LevelDbMigrations::RunMigrations(_db.get());

  LevelDbMigrations::SchemaVersion latestVersion = LevelDbMigrations::ReadSchemaVersion(_db.get());

  // Downgrade to an early version.
  LevelDbMigrations::SchemaVersion downgradeVersion = 1;
  LevelDbMigrations::RunMigrations(_db.get(), downgradeVersion);
  LevelDbMigrations::SchemaVersion postDowngradeVersion =
      LevelDbMigrations::ReadSchemaVersion(_db.get());
  XCTAssertEqual(downgradeVersion, postDowngradeVersion);

  // Verify that we can upgrade again to the latest version.
  LevelDbMigrations::RunMigrations(_db.get());
  LevelDbMigrations::SchemaVersion finalVersion = LevelDbMigrations::ReadSchemaVersion(_db.get());
  XCTAssertEqual(finalVersion, latestVersion);
}

/**
 * Creates the name of a dummy entry to make sure the iteration is correctly bounded.
 */
- (std::string)dummyKeyForTable:(const char *)tableName {
  std::string dummyKey;
  // Magic number that indicates a table name follows. Needed to mimic the prefix to the target
  // table.
  OrderedCode::WriteSignedNumIncreasing(&dummyKey, 5);
  OrderedCode::WriteString(&dummyKey, tableName);
  return dummyKey;
}

@end

NS_ASSUME_NONNULL_END
