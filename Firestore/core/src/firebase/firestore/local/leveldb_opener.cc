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

#include "Firestore/core/src/firebase/firestore/local/leveldb_opener.h"

#include <string>
#include <utility>

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem_detail.h"
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
using util::Path;
using util::RecursivelyCreateDir;
using util::Status;
using util::StatusOr;
using util::StringFormat;

constexpr const char* kReservedPathComponent = "firestore";

Status FromCause(const std::string& message,
                 const firebase::firestore::util::Status& cause) {
  if (cause.ok()) return cause;

  return Status(cause.code(), message).CausedBy(cause);
}

}  // namespace

LevelDbOpener::LevelDbOpener(
    firebase::firestore::core::DatabaseInfo database_info)
    : database_info_(std::move(database_info)) {
}

Path LevelDbOpener::AppDataDir() {
  if (!ok()) return {};

  auto maybe_dir = util::AppDataDir(kReservedPathComponent);
  if (!maybe_dir.ok()) {
    status_ =
        FromCause("Failed to find the App data directory for the current user",
                  maybe_dir.status());
    return {};
  }
  return maybe_dir.ValueOrDie();
}

Path LevelDbOpener::LegacyDocumentsDir() {
  if (!ok()) return {};

  auto maybe_dir = util::LegacyDocumentsDir(kReservedPathComponent);
  if (!maybe_dir.ok()) {
    status_ =
        FromCause("Failed to find the Documents directory for the current user",
                  maybe_dir.status());
    return {};
  }
  return maybe_dir.ValueOrDie();
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

bool LevelDbOpener::PreferredExists(const Path& app_data_dir) {
  if (!ok()) return false;

  preferred_dir_ = StorageDir(app_data_dir);
  preferred_exists_ = IsDirectory(preferred_dir_);

  LOG_DEBUG("LevelDB storage dir %s: %s",
            (preferred_exists_ ? "exists" : "does not exist"),
            preferred_dir_.ToUtf8String());
  return preferred_exists_;
}

void LevelDbOpener::MaybeMigrate(const Path& legacy_docs_dir) {
  if (!ok() || preferred_exists_) return;

  Path legacy_dir = StorageDir(legacy_docs_dir);
  if (!IsDirectory(legacy_dir)) return;

  // At this point the legacy location exists and the preferred location doesn't
  // so just move into place.
  LOG_DEBUG("Migrating LevelDB storage from legacy location: %s",
            legacy_dir.ToUtf8String());

  Path preferred_parent = preferred_dir_.Dirname();
  Status created = RecursivelyCreateDir(preferred_parent);
  if (!created.ok()) {
    std::string message =
        StringFormat("Could not create LevelDB data directory %s",
                     preferred_parent.ToUtf8String());
    status_ = FromCause(message, created);
    return;
  }

  Status renamed = util::Rename(legacy_dir, preferred_dir_);
  if (!renamed.ok()) {
    std::string message =
        StringFormat("Failed to migrate LevelDB data from %s to %s",
                     legacy_dir.ToUtf8String(), preferred_dir_.ToUtf8String());
    status_ = FromCause(message, renamed);
    return;
  }

  RecursivelyCleanupLegacyDirs(legacy_dir, legacy_docs_dir);
}

void LevelDbOpener::RecursivelyCleanupLegacyDirs(
    firebase::firestore::util::Path legacy_dir,
    const firebase::firestore::util::Path& container_dir) {
  // The legacy_dir must be within the container_dir.
  HARD_ASSERT(absl::StartsWith(legacy_dir.ToUtf8String(),
                               container_dir.ToUtf8String()));

  // The container directory contains a trailing "firestore" component
  HARD_ASSERT(
      absl::EndsWith(container_dir.ToUtf8String(), kReservedPathComponent));

  Path parent_most = container_dir.Dirname();
  for (; legacy_dir != parent_most; legacy_dir = legacy_dir.Dirname()) {
    Status is_dir = util::IsDirectory(legacy_dir);
    if (is_dir.ok()) {
      if (util::IsEmptyDir(legacy_dir)) {
        Status removed = util::detail::DeleteDir(legacy_dir);
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

util::StatusOr<std::unique_ptr<LevelDbPersistence>> LevelDbOpener::Create(
    const LruParams& lru_params) {
  if (!ok()) return status_;

  Serializer remote_serializer(database_info_.database_id());
  LocalSerializer local_serializer(std::move(remote_serializer));

  return LevelDbPersistence::Create(preferred_dir_, std::move(local_serializer),
                                    lru_params);
}

bool LevelDbOpener::IsDirectory(const Path& path) {
  Status is_dir = util::IsDirectory(path);
  switch (is_dir.code()) {
    case Error::Ok:
      return true;

    case Error::NotFound:
      return false;

    default:
      status_ = FromCause("Failed to check directory", is_dir);
      return false;
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
