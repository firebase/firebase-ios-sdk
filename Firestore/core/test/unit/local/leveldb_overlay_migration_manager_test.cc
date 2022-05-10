/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/local/leveldb_overlay_migration_manager.h"

#include <initializer_list>
#include <memory>
#include <string>

#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/local/local_write_result.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/util/ordered_code.h"
#include "Firestore/core/test/unit/local/counting_query_engine.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/memory/memory.h"
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
using model::MutableDocument;
using model::Mutation;
using util::Path;
using testutil::Doc;
using testutil::Key;
using testutil::Map;
using testutil::DeleteMutation;
using testutil::PatchMutation;
using testutil::SetMutation;

class LevelDbOverlayMigrationManagerTest : public testing::Test {
 protected:
  void SetUp() override;
  void TearDown() override;

  void WriteRemoteDocument(const MutableDocument& doc);
  void WriteMutation(const Mutation& mutation);

  Path dir_;
  std::unique_ptr<LevelDbPersistence> persistence_ = nullptr;
  std::unique_ptr<QueryEngine> query_engine_ = nullptr;
  std::unique_ptr<LocalStore> local_store_ = nullptr;
  std::unique_ptr<LocalSerializer> serializer_ = nullptr;
};

void LevelDbOverlayMigrationManagerTest::SetUp() {
  dir_ = LevelDbDir();

  serializer_ = absl::make_unique<LocalSerializer>(MakeLocalSerializer());
  query_engine_ = absl::make_unique<CountingQueryEngine>();
  persistence_ = LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default()).ValueOrDie();
  local_store_ = absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(), credentials::User::Unauthenticated());
  local_store_->Start();
}

void LevelDbOverlayMigrationManagerTest::TearDown() {
  persistence_->Shutdown();
}

void LevelDbOverlayMigrationManagerTest::WriteRemoteDocument(const MutableDocument& doc) {
  persistence_->Run("WriteRemoteDocument", [&] {
    persistence_->remote_document_cache()->Add(doc, doc.read_time());
  });
}

void LevelDbOverlayMigrationManagerTest::WriteMutation(const Mutation& mutation) {
  local_store_->WriteLocally({std::move(mutation)});
}

TEST_F(LevelDbOverlayMigrationManagerTest, CreateOverlayFromSet) {
  WriteRemoteDocument(Doc("foo/bar", 2, Map("it", "original")));
  WriteMutation(SetMutation("foo/bar", Map("foo", "bar")));

  persistence_->Run("WriteRemoteDocument", [&] {
    auto doc = persistence_->remote_document_cache()->Get(Key("foo/bar"));
    auto key = doc.key();
    auto value = doc.value();
    ASSERT_EQ(Key("foo/bar"), key);
    ASSERT_EQ(*Map("it", "original"), value);
    });

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  persistence_ = LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default()).ValueOrDie();
  local_store_ = absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(), credentials::User::Unauthenticated());
  local_store_->Start();

  persistence_->Run("", [&]{
    auto overlay = persistence_->GetDocumentOverlayCache(credentials::User::Unauthenticated())
                       ->GetOverlay(Key("foo/bar"));
    EXPECT_EQ(
        SetMutation("foo/bar", Map("foo", "bar")), overlay.value().mutation());
  });

  EXPECT_EQ(Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations(), local_store_->ReadDocument(Key("foo/bar")));

  // SQLiteOverlayMigrationManager migrationManager =
  //     (SQLiteOverlayMigrationManager) persistence.getOverlayMigrationManager();
  // assertFalse(migrationManager.hasPendingOverlayMigration());
}

}  // namespace


}  // namespace local
}  // namespace firestore
}  // namespace firebase
