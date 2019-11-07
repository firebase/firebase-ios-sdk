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

#if _WIN32

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"

#include <Shlobj.h>

#include <utility>

#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"

namespace firebase {
namespace firestore {
namespace local {

using util::Path;
using util::Status;
using util::StatusOr;

StatusOr<Path> LevelDbPersistence::AppDataDirectory() {
  wchar_t* path = nullptr;
  HRESULT hr = SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path);
  if (FAILED(hr)) {
    CoTaskMemFree(path);
    return Status::FromLastError(
        HRESULT_CODE(hr),
        "Failed to find the local application data directory");
  }

  Path result = Path::FromUtf16(path, wcslen(path));
  CoTaskMemFree(path);
  return std::move(result);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // _WIN32
