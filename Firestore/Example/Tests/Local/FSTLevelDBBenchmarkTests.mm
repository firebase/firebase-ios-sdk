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

static void BM_StringCreation(benchmark::State& state) {
  for (auto _ : state) {
    std::string empty_string;
  }
}

BENCHMARK(BM_StringCreation);

std::string DocumentData() {
  // TODO(gsoltis): implement this, return a large string
  return "";
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
    std::string empty_buffer;
    for (int i = 0; i < _numDocuments; i++) {
      FSTDocumentKey *docKey = [FSTDocumentKey keyWithPathString:[NSString stringWithFormat:@"doc_%i", i]];
      std::string docKeyString = [FSTLevelDBRemoteDocumentKey keyWithDocumentKey:docKey];
      txn.Put(docKeyString, DocumentData());
      txn.Put([FSTLevelDBDocumentTargetKey keyWithDocumentKey:docKey targetID:_targetID], empty_buffer);
      txn.Put([FSTLevelDBTargetDocumentKey keyWithTargetID:_targetID documentKey:docKey], empty_buffer);
    }
    txn.Commit();
    _db.ptr()->CompactRange("", <#const leveldb::Slice * end#>)
  }

 protected:
  FSTLevelDB *_db;
  // Arbitrary target ID
  FSTTargetID _targetID = 1;
  int _numDocuments = 10;

};

// Plan: write a bunch of key/value pairs w/ empty strings (index entries)
// Write a couple large values (documents)
// In each test, either overwrite index entries and documents, or just documents

BENCHMARK_F(LevelDBFixture, TripleWrite)(benchmark::State& state) {
  for (auto _ : state) {
    LevelDbTransaction txn(_db.ptr.get(), "benchmark");

    txn.Commit();
  }
}

static void singleWriteCase() {

}

@interface FSTLevelDBBenchmarkTests : XCTestCase
@end

@implementation FSTLevelDBBenchmarkTests

- (void)testRunBenchmarks {
  char name[] = "Benchmarks";
  int argc = 1;
  char* argv = &name[0];
  benchmark::Initialize(&argc, &argv);
  benchmark::RunSpecifiedBenchmarks();
}

@end

NS_ASSUME_NONNULL_END