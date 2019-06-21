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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include <cstdint>

#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "benchmark/benchmark.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbRemoteDocumentKey;
using firebase::firestore::local::LevelDbTargetDocumentKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::TargetId;
using firebase::firestore::util::StringFormat;

namespace {

// Pre-existing document size
const int kDocumentSize = 1024 * 2;  // 2 kb

std::string DocumentData() {
  return std::string(kDocumentSize, 'a');
}

std::string UpdatedDocumentData(int64_t documentSize) {
  return std::string(documentSize, 'b');
}

NSString *LevelDBDir() {
  NSFileManager *files = [NSFileManager defaultManager];
  NSString *dir =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"FSTPersistenceTestHelpers"];
  if ([files fileExistsAtPath:dir]) {
    // Delete the directory first to ensure isolation between runs.
    NSError *error;
    BOOL success = [files removeItemAtPath:dir error:&error];
    if (!success) {
      [NSException raise:NSInternalInconsistencyException
                  format:@"Failed to clean up leveldb path %@: %@", dir, error];
    }
  }
  return dir;
}

FSTLevelDB *LevelDBPersistence() {
  NSString *dir = LevelDBDir();
  auto remoteSerializer = [[FSTSerializerBeta alloc] initWithDatabaseID:DatabaseId("p", "d")];
  auto serializer = [[FSTLocalSerializer alloc] initWithRemoteSerializer:remoteSerializer];
  auto db = [[FSTLevelDB alloc] initWithDirectory:dir serializer:serializer];

  NSError *error;
  BOOL success = [db start:&error];
  if (!success) {
    [NSException raise:NSInternalInconsistencyException
                format:@"Failed to create leveldb path %@: %@", dir, error];
  }

  return db;
}

}  // namespace

class LevelDBFixture : public benchmark::Fixture {
  void SetUp(benchmark::State &state) override {
    db_ = LevelDBPersistence();
    FillDB();
  }

  void TearDown(benchmark::State &state) override {
    db_ = nil;
  }

  void FillDB() {
    LevelDbTransaction txn(db_.ptr, "benchmark");

    for (int i = 0; i < numDocuments_; i++) {
      auto docKey = DocumentKey::FromPathString(StringFormat("docs/doc_%i", i));
      std::string docKeyString = LevelDbRemoteDocumentKey::Key(docKey);
      txn.Put(docKeyString, DocumentData());
      WriteIndex(&txn, docKey);
    }
    txn.Commit();
    // Force a write to disk to simulate startup situation
    db_.ptr->CompactRange(NULL, NULL);
  }

 protected:
  void WriteIndex(LevelDbTransaction *txn, const DocumentKey &docKey) {
    // Arbitrary target ID
    TargetId targetID = 1;
    txn->Put(LevelDbDocumentTargetKey::Key(docKey, targetID), emptyBuffer_);
    txn->Put(LevelDbTargetDocumentKey::Key(targetID, docKey), emptyBuffer_);
  }

  FSTLevelDB *db_;
  int numDocuments_ = 10;
  std::string emptyBuffer_;
};

// Plan: write a bunch of key/value pairs w/ empty strings (index entries)
// Write a couple large values (documents)
// In each test, either overwrite index entries and documents, or just documents

BENCHMARK_DEFINE_F(LevelDBFixture, RemoteEvent)(benchmark::State &state) {  // NOLINT
  bool writeIndexes = static_cast<bool>(state.range(0));
  int64_t documentSize = state.range(1);
  int64_t docsToUpdate = state.range(2);
  std::string documentUpdate = UpdatedDocumentData(documentSize);
  for (const auto &_ : state) {
    LevelDbTransaction txn(db_.ptr, "benchmark");
    for (int i = 0; i < docsToUpdate; i++) {
      auto docKey = DocumentKey::FromPathString(StringFormat("docs/doc_%i", i));
      if (writeIndexes) WriteIndex(&txn, docKey);
      std::string docKeyString = LevelDbRemoteDocumentKey::Key(docKey);
      txn.Put(docKeyString, documentUpdate);
    }
    txn.Commit();
  }
}

/**
 * Adjust ranges to control what test cases run. Outermost loop controls whether or
 * not indexes are written, the inner loops control size of document writes and number
 * of document writes.
 */
static void TestCases(benchmark::internal::Benchmark *b) {
  for (int writeIndexes = 0; writeIndexes <= 1; writeIndexes++) {
    for (int documentSize = 1 << 10; documentSize <= 1 << 20; documentSize *= 4) {
      for (int docsToUpdate = 1; docsToUpdate <= 5; docsToUpdate++) {
        b->Args({writeIndexes, documentSize, docsToUpdate});
      }
    }
  }
}

BENCHMARK_REGISTER_F(LevelDBFixture, RemoteEvent)
    ->Apply(TestCases)
    ->Unit(benchmark::kMicrosecond)
    ->Repetitions(5);

@interface FSTLevelDBBenchmarkTests : XCTestCase
@end

@implementation FSTLevelDBBenchmarkTests

- (void)testRunBenchmarks {
  // Enable to run benchmarks.
  char *argv[3] = {const_cast<char *>("Benchmarks"),
                   const_cast<char *>("--benchmark_out=/tmp/leveldb_benchmark"),
                   const_cast<char *>("--benchmark_out_format=csv")};
  int argc = 3;
  benchmark::Initialize(&argc, argv);
  benchmark::RunSpecifiedBenchmarks();
}

@end

NS_ASSUME_NONNULL_END
