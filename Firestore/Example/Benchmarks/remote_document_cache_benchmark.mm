/*
 * Copyright 2020 Google LLC
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

#import <FirebaseFirestore/FirebaseFirestore.h>
#import "FirebaseCore/Extension/FIRAppInternal.h"

#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"
#include "benchmark/benchmark.h"

namespace {

using firebase::firestore::testutil::AppForUnitTesting;
using firebase::firestore::util::CreateAutoId;
using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;

FIRFirestore* OpenFirestore() {
  FIRApp* app = AppForUnitTesting();
  auto db = [FIRFirestore firestoreForApp:app];
  auto settings = db.settings;

  // Default to running against the emulator because we're evaluating local execution speed.
  settings.host = @"localhost:8080";
  settings.sslEnabled = NO;

  // The default is the main queue and this deadlocks because the benchmark does not start an event
  // loop and just runs on the main thread.
  settings.dispatchQueue = dispatch_queue_create("results", DISPATCH_QUEUE_SERIAL);
  db.settings = settings;

  return db;
}

NSMutableDictionary<NSString*, id>* MakeDocumentData() {
  NSMutableDictionary<NSString*, id>* doc = [[NSMutableDictionary alloc] init];
  NSString* value = MakeNSString(std::string('a', 100));

  // Create keys "a", "b", "c", ..., "j", each associated with the 100 byte
  // value. This makes the total document size ~1 kb.
  std::string key_bytes("a");
  for (int i = 0; i < 10; i++) {
    key_bytes[0] = static_cast<char>('a' + i);
    doc[MakeNSString(key_bytes)] = value;
  }
  return doc;
}

FIRQuerySnapshot* GetDocumentsFromCache(FIRQuery* query) {
  __block FIRQuerySnapshot* result;
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  [query getDocumentsWithSource:FIRFirestoreSourceCache
                     completion:^(FIRQuerySnapshot* snap, NSError* error) {
                       HARD_ASSERT(error == nil, "Failed: %s", MakeString([error description]));
                       result = snap;
                       dispatch_semaphore_signal(done);
                     }];
  dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
  return result;
}

FIRQuerySnapshot* GetDocumentsFromServer(FIRQuery* query) {
  __block FIRQuerySnapshot* result;
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  [query getDocumentsWithSource:FIRFirestoreSourceServer
                     completion:^(FIRQuerySnapshot* snap, NSError* error) {
                       HARD_ASSERT(error == nil, "Failed: %s", MakeString([error description]));
                       result = snap;
                       dispatch_semaphore_signal(done);
                     }];
  dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
  return result;
}

void WaitForPendingWrites(FIRFirestore* db) {
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  [db waitForPendingWritesWithCompletion:^(NSError*) {
    dispatch_semaphore_signal(done);
  }];
  dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}

void WriteDocs(FIRCollectionReference* collection, int64_t count, bool match) {
  auto doc = MakeDocumentData();
  for (int64_t i = 0; i < count; i++) {
    doc[@"match"] = @(match);
    FIRDocumentReference* ref = [collection documentWithAutoID];
    [ref setData:doc];
  }
  WaitForPendingWrites(collection.firestore);
}

void Shutdown(FIRFirestore* db) {
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  [db terminateWithCompletion:^(NSError*) {
    dispatch_semaphore_signal(done);
  }];
  dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}

void BM_QueryIndexFree(benchmark::State& state) {
  int64_t matching_docs = state.range(0);
  int64_t total_docs = state.range(1);

  FIRFirestore* db = OpenFirestore();
  auto collection = [db collectionWithPath:MakeNSString("docs-" + CreateAutoId())];
  WriteDocs(collection, matching_docs, /*match=*/true);
  WriteDocs(collection, total_docs - matching_docs, /*match=*/false);

  FIRQuery* query = [collection queryWhereField:@"match" isEqualTo:@YES];

  // Query the server to force the target tables to be updated.
  GetDocumentsFromServer(query);

  for (auto _ : state) {
    auto docs = GetDocumentsFromCache(query);
    (void)docs;
  }

  Shutdown(db);
}
BENCHMARK(BM_QueryIndexFree)
    ->Unit(benchmark::kMicrosecond)
    ->Args({0, 1})
    ->Args({1, 1})
    ->Args({1, 10})
    ->Args({10, 10})
    ->Args({1, 100})
    ->Args({100, 100})
    ->Args({1, 1000})
    ->Args({10, 1000})
    ->Args({100, 1000})
    ->Args({1000, 1000});

void BM_QueryMatching(benchmark::State& state) {
  int64_t matching_docs = state.range(0);
  int64_t total_docs = state.range(1);

  FIRFirestore* db = OpenFirestore();
  auto collection = [db collectionWithPath:MakeNSString("docs-" + CreateAutoId())];
  WriteDocs(collection, matching_docs, /*match=*/true);
  WriteDocs(collection, total_docs - matching_docs, /*match=*/false);

  for (auto _ : state) {
    auto docs = GetDocumentsFromCache([collection queryWhereField:@"match" isEqualTo:@YES]);
    (void)docs;
  }

  Shutdown(db);
}
BENCHMARK(BM_QueryMatching)
    ->Unit(benchmark::kMicrosecond)
    ->Args({0, 1})
    ->Args({1, 1})
    ->Args({1, 10})
    ->Args({10, 10})
    ->Args({1, 100})
    ->Args({100, 100})
    ->Args({1, 1000})
    ->Args({10, 1000})
    ->Args({100, 1000})
    ->Args({1000, 1000});

void BM_QueryAll(benchmark::State& state) {
  int64_t total_docs = state.range(0);

  FIRFirestore* db = OpenFirestore();
  auto collection = [db collectionWithPath:MakeNSString("docs-" + CreateAutoId())];
  WriteDocs(collection, total_docs, /*match=*/true);

  for (auto _ : state) {
    auto docs = GetDocumentsFromCache(collection);
    (void)docs;
  }

  Shutdown(db);
}

BENCHMARK(BM_QueryAll)->Unit(benchmark::kMicrosecond)->Arg(1)->Arg(10)->Arg(100)->Arg(1000);

}  // namespace
