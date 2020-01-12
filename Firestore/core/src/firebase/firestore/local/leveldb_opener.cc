/*
 * Copyright 2020 Google
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

#include "Firestore/core/src/firebase/firestore/local/leveldb_opener.h"

#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/strings/match.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::DatabaseInfo;
using remote::Serializer;
using util::Filesystem;
using util::Path;
using util::Status;
using util::StatusOr;
using util::StringFormat;

constexpr const char* kReservedPathComponent = "firestore";

Status FromCause(const std::string& message, const Status& cause) {
  if (cause.ok()) return cause;

  return Status(cause.code(), message).CausedBy(cause);
}

}  // namespace

LevelDbOpener::LevelDbOpener(DatabaseInfo database_info, Filesystem* fs)
    : database_info_(std::move(database_info)),
      fs_(fs ? fs : Filesystem::Default()) {
}

LevelDbOpener::LevelDbOpener(DatabaseInfo database_info,
                             Path firestore_app_data_dir)
    : database_info_(std::move(database_info)),
      app_data_dir_(std::move(firestore_app_data_dir)),
      fs_(Filesystem::Default()) {
}

util::StatusOr<std::unique_ptr<LevelDbPersistence>> LevelDbOpener::Create(
    const LruParams& lru_params) {
  auto maybe_dir = PrepareDataDir();
  if (!maybe_dir.ok()) return maybe_dir.status();
  Path db_data_dir = maybe_dir.ValueOrDie();

  LOG_DEBUG("Using %s for LevelDB storage", db_data_dir.ToUtf8String());

  Serializer remote_serializer(database_info_.database_id());
  LocalSerializer local_serializer(std::move(remote_serializer));

  return LevelDbPersistence::Create(db_data_dir, std::move(local_serializer),
                                    lru_params);
}

template <typename T, typename Function>
auto Map(StatusOr<T> maybe_value, Function&& function)
    -> StatusOr<decltype(function(std::move(maybe_value).ValueOrDie()))> {
  if (!maybe_value.ok()) {
    return maybe_value.status();
  }
  T value = maybe_value.ValueOrDie();
  return function(value);
}

StatusOr<Path> LevelDbOpener::LevelDbDataDir() {
  StatusOr<Path> maybe_dir = FirestoreAppDataDir();
  if (!maybe_dir.ok()) return maybe_dir;
  return StorageDir(maybe_dir.ValueOrDie());
}

StatusOr<Path> LevelDbOpener::PrepareDataDir() {
  Status status;
  bool exists = false;

  // Check for the preferred location. If it exists, we're done.
  Path db_data_dir;
  std::tie(status, db_data_dir, exists) =
      StorageDirExists(FirestoreAppDataDir());
  if (!status.ok()) {
    return status;
  } else if (exists) {
    return db_data_dir;
  }

  // The preferred dir doesn't exist so check for the legacy location. If it
  // exists, migrate.
  Path legacy_db_data_dir;
  std::tie(status, legacy_db_data_dir, exists) =
      StorageDirExists(FirestoreLegacyAppDataDir());
  if (!status.ok()) {
    return status;
  } else if (exists) {
    return MigrateDataDir(legacy_db_data_dir, db_data_dir);
  } else {
    // Either we couldn't find the legacy directory or this platform has no
    // legacy directory so create the new directory.
    Status created = fs_->RecursivelyCreateDir(db_data_dir);
    if (!created.ok()) {
      std::string message =
          StringFormat("Could not create LevelDB data directory %s",
                       db_data_dir.ToUtf8String());

      return FromCause(message, created);
    }

    return db_data_dir;
  }
}

std::tuple<Status, Path, bool> LevelDbOpener::StorageDirExists(
    util::StatusOr<util::Path> maybe_app_data_dir) {
  if (!maybe_app_data_dir.ok()) {
    if (maybe_app_data_dir.status().code() == Error::Unimplemented) {
      return std::make_tuple(Status::OK(), Path(), false);
    } else {
      return std::make_tuple(maybe_app_data_dir.status(), Path(), false);
    }
  }

  Path app_data_dir = maybe_app_data_dir.ValueOrDie();
  Path instance_dir = StorageDir(app_data_dir);
  Status is_dir = fs_->IsDirectory(instance_dir);
  if (is_dir.ok()) {
    return std::make_tuple(Status::OK(), instance_dir, true);
  } else if (is_dir.code() == Error::NotFound) {
    return std::make_tuple(Status::OK(), instance_dir, false);
  } else {
    return std::make_tuple(is_dir, Path(), false);
  }
}

StatusOr<Path> LevelDbOpener::FirestoreAppDataDir() {
  if (app_data_dir_.empty()) {
    auto maybe_dir = fs_->AppDataDir(kReservedPathComponent);
    if (!maybe_dir.ok()) {
      return FromCause(
          "Failed to find the App data directory for the current user",
          maybe_dir.status());
    }
    app_data_dir_ = std::move(maybe_dir).ValueOrDie();
  }
  return app_data_dir_;
}

StatusOr<Path> LevelDbOpener::FirestoreLegacyAppDataDir() {
  if (legacy_app_data_dir_.empty()) {
    auto maybe_dir = fs_->LegacyDocumentsDir(kReservedPathComponent);
    if (!maybe_dir.ok()) {
      return FromCause(
          "Failed to find the Documents directory for the current user",
          maybe_dir.status());
    }
    legacy_app_data_dir_ = std::move(maybe_dir).ValueOrDie();
  }
  return legacy_app_data_dir_;
}

Path LevelDbOpener::StorageDir(const Path& base_path) {
  // Use two different path formats:
  //
  //   * persistence_key / project_id . database_id / name
  //   * persistence_key / project_id / name
  //
  // project_ids are DNS-compatible names and cannot contain dots so there's
  // no danger of collisions.
  std::string project_key = database_info_.database_id().project_id();
  if (!database_info_.database_id().IsDefaultDatabase()) {
    absl::StrAppend(&project_key, ".",
                    database_info_.database_id().database_id());
  }

  // Reserve one additional path component to allow multiple physical databases
  return Path::JoinUtf8(base_path, database_info_.persistence_key(),
                        project_key, "main");
}

StatusOr<Path> LevelDbOpener::MigrateDataDir(
    const firebase::firestore::util::Path& legacy_db_data_dir,
    const firebase::firestore::util::Path& db_data_dir) {
  // At this point the legacy location exists and the preferred location doesn't
  // so just move into place.
  LOG_DEBUG(
      "Migrating LevelDB storage from legacy location: %s\nMigrating to: %s",
      legacy_db_data_dir.ToUtf8String(), db_data_dir.ToUtf8String());

  Path db_data_parent = db_data_dir.Dirname();
  Status created = fs_->RecursivelyCreateDir(db_data_parent);
  if (!created.ok()) {
    std::string message =
        StringFormat("Could not create LevelDB data directory %s",
                     db_data_parent.ToUtf8String());
    LOG_ERROR("Migration failed: %s. Existing data unchanged.", message);
    return FromCause(message, created);
  }

  Status renamed = fs_->Rename(legacy_db_data_dir, db_data_dir);
  if (!renamed.ok()) {
    std::string message = StringFormat(
        "Failed to migrate LevelDB data from %s to %s",
        legacy_db_data_dir.ToUtf8String(), db_data_dir.ToUtf8String());
    LOG_ERROR("Migration failed: %s. Existing data unchanged.", message);
    return FromCause(message, renamed);
  }

  RecursivelyCleanupLegacyDirs(legacy_db_data_dir);
  return db_data_dir;
}

void LevelDbOpener::RecursivelyCleanupLegacyDirs(Path legacy_dir) {
  // The legacy_dir must be within the container_dir.
  HARD_ASSERT(!legacy_app_data_dir_.empty());
  HARD_ASSERT(absl::StartsWith(legacy_dir.ToUtf8String(),
                               legacy_app_data_dir_.ToUtf8String()));

  // The container directory contains a trailing "firestore" component
  HARD_ASSERT(absl::EndsWith(legacy_app_data_dir_.ToUtf8String(),
                             kReservedPathComponent));

  Path parent_most = legacy_app_data_dir_.Dirname();
  for (; legacy_dir != parent_most; legacy_dir = legacy_dir.Dirname()) {
    Status is_dir = fs_->IsDirectory(legacy_dir);
    if (is_dir.ok()) {
      if (util::IsEmptyDir(legacy_dir)) {
        Status removed = fs_->RemoveDir(legacy_dir);
        if (!removed.ok()) {
          LOG_WARN("Could not remove directory %s: %s",
                   legacy_dir.ToUtf8String(), removed.ToString());
          break;
        }
      }

    } else if (is_dir.code() != Error::NotFound) {
      LOG_WARN("Could not remove directory %s: %s", legacy_dir.ToUtf8String(),
               is_dir.ToString());
      break;
    }
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
