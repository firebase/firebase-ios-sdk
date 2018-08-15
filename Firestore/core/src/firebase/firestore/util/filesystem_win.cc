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

#include "Firestore/core/src/firebase/firestore/util/filesystem.h"

#if defined(_WIN32)

#include <windows.h>

#include <cerrno>
#include <string>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace util {

Status IsDirectory(const Path& path) {
  DWORD attrs = ::GetFileAttributesW(path.c_str());
  if (attrs == INVALID_FILE_ATTRIBUTES) {
    DWORD error = ::GetLastError();
    return Status::FromLastError(error, path.ToUtf8String());
  }
  if (attrs & FILE_ATTRIBUTE_DIRECTORY) {
    return Status::OK();
  }

  return Status{FirestoreErrorCode::FailedPrecondition, path.ToUtf8String()};
}

Path TempDir() {
  // Returns a null-terminated string with a trailing backslash.
  wchar_t buffer[MAX_PATH + 1];
  DWORD count = ::GetTempPathW(MAX_PATH, buffer);
  HARD_ASSERT(count > 0, "Failed to determine temporary directory %s",
              ::GetLastError());
  HARD_ASSERT(count <= MAX_PATH, "Invalid temporary path longer than MAX_PATH");

  return Path::FromUtf16(buffer, count);
}

namespace detail {

Status CreateDir(const Path& path) {
  if (::CreateDirectoryW(path.c_str(), nullptr)) {
    return Status::OK();
  }

  DWORD error = ::GetLastError();
  if (error == ERROR_ALREADY_EXISTS) {
    // POSIX returns ENOTDIR if the path exists but isn't a directory. Win32
    // doesn't make this distinction, so figure this out after the fact.
    DWORD attrs = ::GetFileAttributesW(path.c_str());
    if (attrs == INVALID_FILE_ATTRIBUTES) {
      error = ::GetLastError();

    } else if (attrs & FILE_ATTRIBUTE_DIRECTORY) {
      return Status::OK();

    } else {
      return Status{
          FirestoreErrorCode::FailedPrecondition,
          StringFormat(
              "Could not create directory %s: non-directory already exists",
              path.ToUtf8String())};
    }
  }

  return Status::FromLastError(
      error,
      StringFormat("Could not create directory %s", path.ToUtf8String()));
}

Status DeleteDir(const Path& path) {
  if (::RemoveDirectoryW(path.c_str())) {
    return Status::OK();
  }

  DWORD error = ::GetLastError();
  if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
    return Status::OK();
  }

  return Status::FromLastError(
      error,
      StringFormat("Could not delete directory %s", path.ToUtf8String()));
}

Status DeleteFile(const Path& path) {
  if (::DeleteFileW(path.c_str())) {
    return Status::OK();
  }

  DWORD error = ::GetLastError();
  if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
    return Status::OK();
  }

  return Status::FromLastError(
      error, StringFormat("Could not delete file %s", path.ToUtf8String()));
}

Status RecursivelyDeleteDir(const Path& parent) {
  Status result;
  auto fail = [&](DWORD error) {
    result.Update(Status::FromLastError(
        error,
        StringFormat("Could not delete directory: %s", parent.ToUtf8String())));
    return result;
  };

  WIN32_FIND_DATAW find_data;
  Path pattern = parent.AppendUtf16(L"*", 1);
  HANDLE find_handle = ::FindFirstFileW(pattern.c_str(), &find_data);
  if (find_handle == INVALID_HANDLE_VALUE) {
    DWORD error = ::GetLastError();
    if (error == ERROR_FILE_NOT_FOUND) {
      return Status::OK();
    } else {
      return fail(error);
    }
  }

  do {
    wchar_t* name = find_data.cFileName;
    if (wcscmp(name, L".") == 0 || wcscmp(name, L"..") == 0) {
      continue;
    }

    Path child = parent.AppendUtf16(name, wcslen(name));
    RecursivelyDelete(child);
  } while (::FindNextFileW(find_handle, &find_data));

  DWORD error = ::GetLastError();
  if (error != ERROR_NO_MORE_FILES) {
    fail(error);
  }

  if (!::FindClose(find_handle)) {
    return fail(::GetLastError());
  }

  if (result.ok()) {
    result.Update(DeleteDir(parent));
  }

  return result;
}

}  // namespace detail
}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)
