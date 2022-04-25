/*
 * Copyright 2018 Google LLC
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

#include "Firestore/core/src/util/filesystem.h"

#if defined(_WIN32)

#include <shlobj.h>
#include <windows.h>

#include <cerrno>
#include <string>

#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_format.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

StatusOr<Path> Filesystem::AppDataDir(absl::string_view app_name) {
  wchar_t* path = nullptr;
  Defer cleanup([&] { CoTaskMemFree(path); });

  HRESULT hr = SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &path);
  if (FAILED(hr)) {
    return Status::FromLastError(
        HRESULT_CODE(hr),
        "Failed to find the local application data directory");
  }

  Path result = Path::FromUtf16(path, wcslen(path)).AppendUtf8(app_name);
  return std::move(result);
}

StatusOr<Path> Filesystem::LegacyDocumentsDir(absl::string_view) {
  return Status(Error::kErrorUnimplemented,
                "No legacy storage on this platform.");
}

Path Filesystem::TempDir() {
  // Returns a null-terminated string with a trailing backslash.
  wchar_t buffer[MAX_PATH + 1];
  DWORD count = ::GetTempPathW(MAX_PATH, buffer);
  HARD_ASSERT(count > 0, "Failed to determine temporary directory %s",
              ::GetLastError());
  HARD_ASSERT(count <= MAX_PATH, "Invalid temporary path longer than MAX_PATH");

  return Path::FromUtf16(buffer, count);
}

Status Filesystem::IsDirectory(const Path& path) {
  DWORD attrs = ::GetFileAttributesW(path.c_str());
  if (attrs == INVALID_FILE_ATTRIBUTES) {
    DWORD error = ::GetLastError();
    return Status::FromLastError(error, path.ToUtf8String());
  }
  if (attrs & FILE_ATTRIBUTE_DIRECTORY) {
    return Status::OK();
  }

  return Status{Error::kErrorFailedPrecondition, path.ToUtf8String()};
}

StatusOr<int64_t> Filesystem::FileSize(const Path& path) {
  WIN32_FILE_ATTRIBUTE_DATA attrs;
  if (!::GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &attrs)) {
    DWORD error = ::GetLastError();
    return Status::FromLastError(error, path.ToUtf8String());
  }

  LARGE_INTEGER result{};
  result.HighPart = attrs.nFileSizeHigh;
  result.LowPart = attrs.nFileSizeLow;
  return result.QuadPart;
}

Status Filesystem::CreateDir(const Path& path) {
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
          Error::kErrorFailedPrecondition,
          StringFormat(
              "Could not create directory %s: non-directory already exists",
              path.ToUtf8String())};
    }
  }

  return Status::FromLastError(
      error,
      StringFormat("Could not create directory %s", path.ToUtf8String()));
}

Status Filesystem::RemoveDir(const Path& path) {
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

Status Filesystem::RemoveFile(const Path& path) {
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

Status Filesystem::Rename(const Path& from_path, const Path& to_path) {
  if (::MoveFileW(from_path.c_str(), to_path.c_str())) {
    return Status::OK();
  }

  DWORD error = ::GetLastError();
  return Status::FromLastError(
      error, StringFormat("Could not rename file %s to %s",
                          from_path.ToUtf8String(), to_path.ToUtf8String()));
}

namespace {

class WindowsDirectoryIterator : public DirectoryIterator {
 public:
  explicit WindowsDirectoryIterator(const util::Path& path);
  virtual ~WindowsDirectoryIterator();

  void Next() override;
  bool Valid() const override;
  Path file() const override;

 private:
  /** Closes the underlying directory iterator. */
  void Close();

  /** Examines the result of the last read. */
  void Examine();

  /** Advances to the next directory entry. */
  void Advance();

  HANDLE find_handle_ = INVALID_HANDLE_VALUE;
  WIN32_FIND_DATAW find_data_{};
};

WindowsDirectoryIterator::WindowsDirectoryIterator(const util::Path& path)
    : DirectoryIterator{path} {
  Path pattern = parent_.AppendUtf16(L"*", 1);

  find_handle_ = ::FindFirstFileW(pattern.c_str(), &find_data_);
  if (find_handle_ == INVALID_HANDLE_VALUE) {
    DWORD error = ::GetLastError();
    status_ = Status::FromLastError(
        error,
        StringFormat("Could not open directory %s", parent_.ToUtf8String()));
    return;
  }

  // Compared to the POSIX implementation, FindFirstFileW both opens the find
  // handle and reads the first entry (like a combination of calling opendir()
  // and readdir()).
  Examine();
}

WindowsDirectoryIterator::~WindowsDirectoryIterator() {
  Close();
}

void WindowsDirectoryIterator::Close() {
  if (find_handle_ != INVALID_HANDLE_VALUE) {
    if (!::FindClose(find_handle_)) {
      status_ = Status::FromLastError(
          ::GetLastError(),
          StringFormat("Could not close directory %s", parent_.ToUtf8String()));
      HARD_FAIL("%s", status_.ToString());
    }
    find_handle_ = INVALID_HANDLE_VALUE;
  }
}

void WindowsDirectoryIterator::Examine() {
  HARD_ASSERT(status_.ok(), "Examining an errored iterator");

  wchar_t* name = find_data_.cFileName;
  if (wcscmp(name, L".") == 0 || wcscmp(name, L"..") == 0) {
    Advance();
  }
}

void WindowsDirectoryIterator::Advance() {
  HARD_ASSERT(status_.ok(), "Advancing an errored iterator");

  BOOL found = ::FindNextFileW(find_handle_, &find_data_);
  if (!found) {
    DWORD error = ::GetLastError();
    if (error != ERROR_NO_MORE_FILES) {
      status_ = Status::FromLastError(
          error, StringFormat("Could not read %s", parent_.ToUtf8String()));
    }
    Close();
    return;
  }

  Examine();
}

void WindowsDirectoryIterator::Next() {
  HARD_ASSERT(Valid(), "Next() called on an invalid iterator");
  Advance();
}

bool WindowsDirectoryIterator::Valid() const {
  return status_.ok() && find_handle_ != INVALID_HANDLE_VALUE;
}

Path WindowsDirectoryIterator::file() const {
  HARD_ASSERT(Valid(), "file() called on invalid iterator");
  const wchar_t* name = find_data_.cFileName;
  return parent_.AppendUtf16(name, wcslen(name));
}

}  // namespace

std::unique_ptr<DirectoryIterator> DirectoryIterator::Create(
    const util::Path& path) {
  return absl::make_unique<WindowsDirectoryIterator>(path);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)
