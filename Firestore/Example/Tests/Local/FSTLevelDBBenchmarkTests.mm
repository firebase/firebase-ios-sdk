#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <Firestore/Source/Model/FSTDocumentKey.h>

#include "benchmark/benchmark.h"
#include "gtest/gtest.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbTransaction;

static const int kDocumentSize = 1024 * 2;  // 2 kb

std::string DocumentData() {
  return std::string(kDocumentSize, 'a');
}

std::string UpdatedDocumentData(int documentSize) {
  return std::string(documentSize, 'b');
}

class LevelDBFixture : public benchmark::Fixture {
  virtual void SetUp(benchmark::State& state) {
    _db = [FSTPersistenceTestHelpers levelDBPersistence];
    FillDB();
  }

  virtual void TearDown(benchmark::State& state) {
    _db = nil;
  }

  void FillDB() {
    LevelDbTransaction txn(_db.ptr.get(), "benchmark");

    for (int i = 0; i < _numDocuments; i++) {
      FSTDocumentKey *docKey = [FSTDocumentKey keyWithPathString:[NSString stringWithFormat:@"docs/doc_%i", i]];
      std::string docKeyString = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:docKey];
      txn.Put(docKeyString, DocumentData());
      WriteIndex(txn, docKey);
    }
    txn.Commit();
    // Force a write to disk to simulate startup
    _db.ptr->CompactRange(NULL, NULL);
  }

 protected:
  void WriteIndex(LevelDbTransaction& txn, FSTDocumentKey *docKey) {
    txn.Put([FSTLevelDBDocumentTargetKey keyWithDocumentKey:docKey targetID:_targetID], _emptyBuffer);
    txn.Put([FSTLevelDBTargetDocumentKey keyWithTargetID:_targetID documentKey:docKey], _emptyBuffer);
  }

  FSTLevelDB *_db;
  // Arbitrary target ID
  FSTTargetID _targetID = 1;
  int _numDocuments = 10;
  std::string _emptyBuffer;

};

// Plan: write a bunch of key/value pairs w/ empty strings (index entries)
// Write a couple large values (documents)
// In each test, either overwrite index entries and documents, or just documents

BENCHMARK_DEFINE_F(LevelDBFixture, RemoteEvent)(benchmark::State& state) {
  bool writeIndexes = state.range(0);
  int documentSize = state.range(1);
  int docsToUpdate = state.range(2);
  std::string documentUpdate = UpdatedDocumentData(documentSize);
  for (auto _ : state) {
    LevelDbTransaction txn(_db.ptr.get(), "benchmark");
    for (int i = 0; i < docsToUpdate; i++) {
      FSTDocumentKey *docKey = [FSTDocumentKey keyWithPathString:[NSString stringWithFormat:@"docs/doc_%i", i]];
      if (writeIndexes) WriteIndex(txn, docKey);
      std::string docKeyString = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:docKey];
      txn.Put(docKeyString, documentUpdate);
    }
    txn.Commit();
  }
}

static void TestCases(benchmark::internal::Benchmark *b) {
  for (int writeIndexes = 0; writeIndexes <= 1; writeIndexes++) {
    for (int documentSize = 1<<10; documentSize <= 1<<20; documentSize *= 4) {
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
  char *argv[3] = {
          "Benchmarks",
          "--benchmark_out=/tmp/leveldb_benchmark",
          "--benchmark_out_format=csv"};
  int argc = 3;
  benchmark::Initialize(&argc, argv);
  benchmark::RunSpecifiedBenchmarks();
}

@end

NS_ASSUME_NONNULL_END