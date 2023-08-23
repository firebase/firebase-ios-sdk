/*
 * Copyright 2023 Google LLC
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

#include <algorithm>
#include <chrono>
#include <cmath>
#include <random>
#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/view.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/local/query_engine_test.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::View;
using core::ViewDocumentChanges;
using model::DocumentKeySet;
using model::DocumentSet;
using model::SnapshotVersion;
using std::chrono::duration_cast;
using std::chrono::milliseconds;
using std::chrono::system_clock;
using testutil::AndFilters;
using testutil::Array;
using testutil::Doc;
using testutil::DocSet;
using testutil::Filter;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
using testutil::OrFilters;
using testutil::PatchMutation;
using testutil::Query;
using testutil::SetMutation;
using testutil::Value;
using testutil::Version;
using testutil::details::AddPairs;

static std::vector<google_firestore_v1_Value> values;

const SnapshotVersion kMissingLastLimboFreeSnapshot = SnapshotVersion::None();

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
}

model::DocumentMap DocumentMap(
    const std::vector<model::MutableDocument>& docs) {
  model::DocumentMap doc_map;
  for (const auto& doc : docs) {
    doc_map = doc_map.insert(doc.key(), doc);
  }
  return doc_map;
}
}  // namespace

INSTANTIATE_TEST_SUITE_P(AutoIndexingExperiment,
                         QueryEngineTest,
                         testing::Values(PersistenceFactory));

class AutoIndexingExperiment : public QueryEngineTestBase {
 public:
  AutoIndexingExperiment() : QueryEngineTestBase(PersistenceFactory()) {
    values.push_back(*Value("Hello world").release());
    values.push_back(*Value(46239847).release());
    values.push_back(*Value(-1984092375).release());
    values.push_back(*Value(NAN).release());
  }

  DocumentSet RunQuery(const core::Query& query,
                       bool is_auto_indexing_enabled,
                       absl::optional<QueryContext>& context) {
    const auto docs = query_engine_.GetDocumentsMatchingQueryForTest(
        query, is_auto_indexing_enabled, context);
    View view(query, DocumentKeySet());
    ViewDocumentChanges view_doc_changes =
        view.ComputeDocumentChanges(docs, {});
    return view.ApplyChanges(view_doc_changes).snapshot()->documents();
  }
};

TEST_F(AutoIndexingExperiment, CombinesIndexedWithNonIndexedResults) {
  persistence_->Run("CombinesIndexedWithNonIndexedResults", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto CreateTestingDocument = [&](std::string base_path, int documentID,
                                     bool is_matched, int num_of_fields) {
      auto fields = Map("match", is_matched);

      // Randomly generate the rest of fields.
      for (int i = 2; i <= num_of_fields; i++) {
        // Randomly select a field in values table.
        int value_index = std::rand() % values.size();

        fields =
            AddPairs(std::move(fields), "field" + std::to_string(i),
                     nanopb::MakeMessage(
                         *model::DeepClone(values[value_index]).release()));
      }

      auto doc = Doc(base_path + "/" + std::to_string(documentID), 1,
                     std::move(fields));
      AddDocuments({doc});

      index_manager_->UpdateIndexEntries(DocumentMap({doc}));
      index_manager_->UpdateCollectionGroup(
          base_path, model::IndexOffset::FromDocument(doc));
    };

    auto CreateTestingCollection =
        [&](std::string base_path, int total_set_count, int portion /*0 - 10*/,
            int num_of_fields /* 1 - 30*/) {
          int document_counter = 0;
          auto rng = std::default_random_engine{};

          // A set contains 10 documents.
          for (int i = 1; i <= total_set_count; i++) {
            // Generate a random order list of 0 ... 9, to make sure the
            // matching documents stay in random positions.
            std::vector<int> indexes;
            for (int index = 0; index < 10; index++) {
              indexes.push_back(index);
            }
            std::shuffle(std::begin(indexes), std::end(indexes), rng);

            // portion% of the set match
            for (int match = 0; match < portion; match++) {
              int currentID = document_counter + indexes[match];
              CreateTestingDocument(base_path, currentID, true, num_of_fields);
            }
            for (int unmatch = portion; unmatch < 10; unmatch++) {
              int currentID = document_counter + indexes[unmatch];
              CreateTestingDocument(base_path, currentID, false, num_of_fields);
            }
            document_counter += 10;
          }
        };

    /** Create mutation for 10% of total documents. */
    auto CreateMutationForCollection = [&](std::string base_path,
                                           int total_set_count) {
      auto rng = std::default_random_engine{};

      std::vector<int> indexes;
      indexes.reserve(total_set_count * 10);

      // Randomly selects 10% of documents.
      for (int index = 0; index < total_set_count * 10; index++) {
        indexes.push_back(index);
      }
      std::shuffle(std::begin(indexes), std::end(indexes), rng);

      for (int i = 0; i < total_set_count; i++) {
        AddMutation(PatchMutation(base_path + "/" + std::to_string(indexes[i]),
                                  Map("a", 5)));
      }
    };

    // Every set contains 10 documents
    const int num_of_set = 100;
    // could overflow. Currently it is safe when numOfSet set to 1000 and
    // running on macbook M1
    std::chrono::duration<double> total_before_index(0);
    std::chrono::duration<double> total_after_index(0);
    int64_t total_document_count = 0;
    int64_t total_result_count = 0;

    // Temperate heuristic, gets when setting numOfSet to 1000.
    // double without = 1;
    // double with = 2;

    for (int total_set_count = 10; total_set_count <= num_of_set;
         total_set_count *= 10) {
      // portion stands for the percentage of documents matching query
      for (int portion = 0; portion <= 10; portion++) {
        for (int num_of_fields = 1; num_of_fields <= 31; num_of_fields += 10) {
          std::string base_path =
              "documentCount" + std::to_string(total_set_count);
          core::Query query =
              Query(base_path).AddingFilter(Filter("match", "==", true));

          // Creates a full matched index for given query.
          index_manager_->CreateTargetIndexes(query.ToTarget());

          CreateTestingCollection(base_path, total_set_count, portion,
                                  num_of_fields);
          CreateMutationForCollection(base_path, total_set_count);

          // runs query using full collection scan.
          absl::optional<QueryContext> context_without_index = QueryContext();
          auto before_auto_start = std::chrono::high_resolution_clock::now();
          DocumentSet results = ExpectFullCollectionScan<DocumentSet>(
              [&] { return RunQuery(query, false, context_without_index); });
          auto before_auto_end = std::chrono::high_resolution_clock::now();
          auto milliseconds_before_auto = before_auto_end - before_auto_start;
          total_before_index += milliseconds_before_auto;
          total_document_count +=
              context_without_index.value().GetDocumentReadCount();
          EXPECT_EQ(portion * total_set_count, results.size());

          // runs query using index look up.
          absl::optional<QueryContext> context_with_index;
          auto auto_start = std::chrono::high_resolution_clock::now();
          results = ExpectOptimizedCollectionScan(
              [&] { return RunQuery(query, true, context_with_index); });
          auto auto_end = std::chrono::high_resolution_clock::now();
          auto millisecond_after_auto = auto_end - auto_start;
          total_after_index += millisecond_after_auto;
          total_result_count += results.size();
          EXPECT_EQ(portion * total_set_count, results.size());
          if (true) {
            std::cout << "total num of docs: " +
                             std::to_string(total_set_count * 10)
                      << std::endl;
            std::cout << "The matching percentage is " + std::to_string(portion)
                      << std::endl;
            std::cout << "milliseconds_before_auto: " +
                             std::to_string(milliseconds_before_auto.count())
                      << std::endl;
            std::cout << "millisecond_after_auto: " +
                             std::to_string(millisecond_after_auto.count())
                      << std::endl;
          }
          if (milliseconds_before_auto > millisecond_after_auto) {
            std::cout << "Auto Indexing saves time when total of documents "
                         "inside collection is " +
                             std::to_string(total_set_count * 10) +
                             ". The matching percentage is " +
                             std::to_string(portion) +
                             "0%. And each document contains " +
                             std::to_string(num_of_fields) + " fields."
                      << std::endl;
          }
        }
      }
    }

    std::cout << "The time heuristic is " +
                     std::to_string(total_before_index.count() /
                                    total_document_count) +
                     " before auto indexing. The time heuristic is " +
                     std::to_string(total_after_index.count() /
                                    total_result_count) +
                     " after auto indexing"
              << std::endl;
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
