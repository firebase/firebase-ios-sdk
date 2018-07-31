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

#include "Firestore/core/src/firebase/firestore/util/filesystem_detail.h"

#include "Firestore/core/src/firebase/firestore/util/filesystem.h"

using firebase::firestore::util::Path;

namespace firebase {
namespace firestore {
namespace util {

Status RecursivelyCreateDir(const Path& path) {
  Status result = detail::CreateDir(path);
  if (result.ok() || result.code() != FirestoreErrorCode::NotFound) {
    // Successfully created the directory, it already existed, or some other
    // unrecoverable error.
    return result;
  }

  // Missing parent
  Path parent = path.Dirname();
  result = RecursivelyCreateDir(parent);
  if (!result.ok()) {
    return result;
  }

  // Successfully created the parent so try again.
  return detail::CreateDir(path);
}

Status RecursivelyDelete(const Path& path) {
  bool is_dir = false;
  if (!Exists(path, &is_dir)) {
    return Status::OK();
  }

  if (is_dir) {
    return detail::RecursivelyDeleteDir(path);
  } else {
    return detail::DeleteFile(path);
  }
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
