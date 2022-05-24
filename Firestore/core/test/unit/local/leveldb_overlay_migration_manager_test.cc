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

#include <memory>

#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/local/local_write_result.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
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
using nanopb::Message;
using testutil::DeletedDoc;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Key;
using testutil::Map;
using testutil::MergeMutation;
using testutil::PatchMutation;
using testutil::SetMutation;
using testutil::Value;
using util::Path;
}  // namespace

class LevelDbOverlayMigrationManagerTest : public testing::Test {
 protected:
  void SetUp() override;
  void TearDown() override;

  void WriteRemoteDocument(const MutableDocument& doc);
  void WriteMutation(const Mutation& mutation);
  void WriteMutations(std::vector<Mutation>&& mutations);

  DocumentOverlayCache* document_overlay_cache() {
    return local_store_->document_overlay_cache_;
  }

  bool has_pending_overlay_migration() {
    return persistence_
        ->GetOverlayMigrationManager(credentials::User::Unauthenticated())
        ->HasPendingOverlayMigration();
  }

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
  // Creates the persistence with schema version before overlay is supported.
  persistence_ = LevelDbPersistence::Create(dir_, /* schema_version */ 7,
                                            *serializer_, LruParams::Default())
                     .ValueOrDie();
  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();
}

void LevelDbOverlayMigrationManagerTest::TearDown() {
  persistence_->Shutdown();
}

void LevelDbOverlayMigrationManagerTest::WriteRemoteDocument(
    const MutableDocument& doc) {
  persistence_->Run("WriteRemoteDocument", [&] {
    persistence_->remote_document_cache()->Add(doc, doc.read_time());
  });
}

void LevelDbOverlayMigrationManagerTest::WriteMutation(
    const Mutation& mutation) {
  WriteMutations({std::move(mutation)});
}

void LevelDbOverlayMigrationManagerTest::WriteMutations(
    std::vector<Mutation>&& mutations) {
  auto result = local_store_->WriteLocally(std::move(mutations));
  // Delete overlays to make sure the overlays we see from tests are migrated
  // by migration manager, not by tests setup.
  persistence_->Run("Delete Overlays For Testing", [&] {
    document_overlay_cache()->RemoveOverlaysForBatchId(result.batch_id());
  });
}

TEST_F(LevelDbOverlayMigrationManagerTest, CreateOverlayFromSet) {
  WriteRemoteDocument(Doc("foo/bar", 2, Map("it", "original")));
  WriteMutation(SetMutation("foo/bar", Map("foo", "bar")));

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  // Create persistence with the current SDK's schema, which should run the
  // migration.
  persistence_ =
      LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default())
          .ValueOrDie();
  persistence_->Run("Verify flag",
                    [&] { EXPECT_TRUE(has_pending_overlay_migration()); });

  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();

  persistence_->Run("Verify mutation", [&] {
    auto overlay = document_overlay_cache()->GetOverlay(Key("foo/bar"));
    EXPECT_EQ(SetMutation("foo/bar", Map("foo", "bar")),
              overlay.value().mutation());
  });

  EXPECT_EQ(Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations(),
            local_store_->ReadDocument(Key("foo/bar")));

  persistence_->Run("Verify flag",
                    [&] { EXPECT_FALSE(has_pending_overlay_migration()); });
}

TEST_F(LevelDbOverlayMigrationManagerTest, SkipsIfAlreadyMigrated) {
  WriteRemoteDocument(Doc("foo/bar", 2, Map("it", "original")));
  WriteMutation(SetMutation("foo/bar", Map("foo", "bar")));

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  // Create persistence with the current SDK's schema, which should run the
  // migration.
  persistence_ =
      LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default())
          .ValueOrDie();
  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();
  EXPECT_EQ(Doc("foo/bar", 2, Map("foo", "bar")).SetHasLocalMutations(),
            local_store_->ReadDocument(Key("foo/bar")));
  persistence_->Run("Verify flag",
                    [&] { EXPECT_FALSE(has_pending_overlay_migration()); });

  // Delete the overlay to verify migration is skipped the second time.
  persistence_->Run("Delete Overlay", [&] {
    document_overlay_cache()->RemoveOverlaysForBatchId(1);
  });

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  // Create persistence with the current SDK's schema, this one no migration
  // should be run.
  persistence_ =
      LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default())
          .ValueOrDie();
  persistence_->Run("Verify flag",
                    [&] { EXPECT_FALSE(has_pending_overlay_migration()); });
  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();

  // No overlay should exist since migration is not run.
  persistence_->Run("Verify overlay", [&] {
    EXPECT_FALSE(
        document_overlay_cache()->GetOverlay(Key("foo/bar")).has_value());
  });
}

TEST_F(LevelDbOverlayMigrationManagerTest, CreateOverlayFromDelete) {
  WriteRemoteDocument(Doc("foo/bar", 2, Map("it", "original")));
  WriteMutation(DeleteMutation("foo/bar"));

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  // Create persistence with the current SDK's schema, which should run the
  // migration.
  persistence_ =
      LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default())
          .ValueOrDie();
  persistence_->Run("Verify flag",
                    [&] { EXPECT_TRUE(has_pending_overlay_migration()); });

  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();

  persistence_->Run("Verify mutation", [&] {
    auto overlay = document_overlay_cache()->GetOverlay(Key("foo/bar"));
    EXPECT_EQ(DeleteMutation("foo/bar"), overlay.value().mutation());
  });

  EXPECT_EQ(DeletedDoc("foo/bar", 2).SetHasLocalMutations(),
            local_store_->ReadDocument(Key("foo/bar")));

  persistence_->Run("Verify flag",
                    [&] { EXPECT_FALSE(has_pending_overlay_migration()); });
}

TEST_F(LevelDbOverlayMigrationManagerTest, CreateOverlayFromPatch) {
  WriteRemoteDocument(Doc("foo/bar", 2, Map("it", "original")));
  std::vector<Message<google_firestore_v1_Value>> array_union;
  array_union.push_back(Value(1));
  WriteMutations(
      {PatchMutation("foo/bar", Map(), {testutil::Increment("it", Value(1))}),
       MergeMutation("foo/newBar", Map(), {},
                     {testutil::ArrayUnion("it", array_union)})});

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  // Create persistence with the current SDK's schema, which should run the
  // migration.
  persistence_ =
      LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default())
          .ValueOrDie();
  persistence_->Run("Verify flag",
                    [&] { EXPECT_TRUE(has_pending_overlay_migration()); });

  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();

  persistence_->Run("Verify mutation", [&] {
    {
      auto overlay = document_overlay_cache()->GetOverlay(Key("foo/bar"));
      EXPECT_EQ(MergeMutation("foo/bar", Map("it", 1), {testutil::Field("it")}),
                overlay.value().mutation());
    }
    {
      auto overlay = document_overlay_cache()->GetOverlay(Key("foo/newBar"));
      EXPECT_EQ(MergeMutation("foo/newBar", Map("it", testutil::Array(1)),
                              {testutil::Field("it")}),
                overlay.value().mutation());
    }
  });

  EXPECT_EQ(Doc("foo/bar", 2, Map("it", 1)).SetHasLocalMutations(),
            local_store_->ReadDocument(Key("foo/bar")));
  EXPECT_EQ(Doc("foo/newBar", 2, Map("it", testutil::Array(1)))
                .SetHasLocalMutations(),
            local_store_->ReadDocument(Key("foo/newBar")));

  persistence_->Run("Verify flag",
                    [&] { EXPECT_FALSE(has_pending_overlay_migration()); });
}

TEST_F(LevelDbOverlayMigrationManagerTest, CreateOverlaysForDifferentUsers) {
  WriteRemoteDocument(Doc("foo/bar", 2, Map("it", "original")));
  WriteMutation(SetMutation("foo/bar", Map("foo", "set-by-unauthenticated")));

  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User("another_user"));
  local_store_->Start();
  WriteMutation(SetMutation("foo/bar", Map("foo", "set-by-another_user")));

  // Switch to new persistence and run migrations
  persistence_->Shutdown();

  // Create persistence with the current SDK's schema, which should run the
  // migration.
  persistence_ =
      LevelDbPersistence::Create(dir_, *serializer_, LruParams::Default())
          .ValueOrDie();
  persistence_->Run("Verify flag",
                    [&] { EXPECT_TRUE(has_pending_overlay_migration()); });

  local_store_ =
      absl::make_unique<LocalStore>(persistence_.get(), query_engine_.get(),
                                    credentials::User::Unauthenticated());
  local_store_->Start();

  persistence_->Run("Verify mutation", [&] {
    {
      auto overlay =
          persistence_
              ->GetDocumentOverlayCache(credentials::User::Unauthenticated())
              ->GetOverlay(Key("foo/bar"));
      EXPECT_EQ(SetMutation("foo/bar", Map("foo", "set-by-unauthenticated")),
                overlay.value().mutation());
    }
    {
      auto overlay =
          persistence_
              ->GetDocumentOverlayCache(credentials::User("another_user"))
              ->GetOverlay(Key("foo/bar"));
      EXPECT_EQ(SetMutation("foo/bar", Map("foo", "set-by-another_user")),
                overlay.value().mutation());
    }
  });

  EXPECT_EQ(Doc("foo/bar", 2, Map("foo", "set-by-unauthenticated"))
                .SetHasLocalMutations(),
            local_store_->ReadDocument(Key("foo/bar")));

  persistence_->Run("Verify flag",
                    [&] { EXPECT_FALSE(has_pending_overlay_migration()); });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
