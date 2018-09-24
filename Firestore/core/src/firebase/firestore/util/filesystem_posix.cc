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

#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <cerrno>
#include <deque>
#include <string>

#include "Firestore/core/src/firebase/firestore/util/filesystem_detail.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/third_party/abseil-cpp/absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

Status IsDirectory(const Path& path) {
  struct stat buffer {};
  if (::stat(path.c_str(), &buffer)) {
    if (errno == ENOENT) {
      // Expected common error case.
      return Status{FirestoreErrorCode::NotFound, path.ToUtf8String()};

    } else if (errno == ENOTDIR) {
      // This is a case where POSIX and Windows differ in behavior in a way
      // that's hard to reconcile from Windows. Under POSIX, ENOTDIR indicates
      // that not only does the path not exist, but that some parent of the
      // path also isn't a directory.
      //
      // Windows, OTOH, returns ERROR_FILE_NOT_FOUND if the file doesn't exist,
      // its immediate parent exists, and the parent is a directory. Otherwise
      // Windows returns ERROR_PATH_NOT_FOUND. To emulate POSIX behavior you
      // have to find the leaf-most existing parent and figure out if it's not a
      // directory.
      //
      // Since we really don't care about this distinction it's easier to
      // resolve this by returning NotFound here.
      return Status{FirestoreErrorCode::NotFound, path.ToUtf8String()};
    } else {
      return Status::FromErrno(errno, path.ToUtf8String());
    }
  }

  if (!S_ISDIR(buffer.st_mode)) {
    return Status{FirestoreErrorCode::FailedPrecondition,
                  StringFormat("Path %s exists but is not a directory",
                               path.ToUtf8String())};
  }

  return Status::OK();
}

#if !defined(__APPLE__)
// See filesystem_apple.mm for an alternative implementation.
Path TempDir() {
  const char* env_tmpdir = getenv("TMPDIR");
  if (env_tmpdir) {
    return Path::FromUtf8(env_tmpdir);
  }

#if defined(__ANDROID__)
  // The /tmp directory doesn't exist as a fallback; each application is
  // supposed to keep its own temporary files. Previously /data/local/tmp may
  // have been reasonable, but current lore points to this being unreliable for
  // writing at higher API levels or certain phone models because default
  // permissions on this directory no longer permit writing.
  //
  // TODO(wilhuff): Validate on recent Android.
#error "Not yet sure about temporary file locations on Android."
  return Path::FromUtf8("/data/local/tmp");

#else
  return Path::FromUtf8("/tmp");
#endif  // defined(__ANDROID__)
}
#endif  // !defined(__APPLE__)

namespace detail {

Status CreateDir(const Path& path) {
  if (::mkdir(path.c_str(), 0777)) {
    if (errno != EEXIST) {
      return Status::FromErrno(
          errno,
          StringFormat("Could not create directory %s", path.ToUtf8String()));
    }
  }

  return Status::OK();
}

Status DeleteDir(const Path& path) {
  if (::rmdir(path.c_str())) {
    if (errno != ENOENT) {
      return Status::FromErrno(
          errno,
          StringFormat("Could not delete directory %s", path.ToUtf8String()));
    }
  }
  return Status::OK();
}

Status DeleteFile(const Path& path) {
  if (::unlink(path.c_str())) {
    if (errno != ENOENT) {
      return Status::FromErrno(
          errno, StringFormat("Could not delete file %s", path.ToUtf8String()));
    }
  }
  return Status::OK();
}

Status RecursivelyDeleteDir(const Path& parent) {
  DirectoryIterator iter(parent);
  for (; iter.Valid(); iter.Next()) {
    Status status = RecursivelyDelete(iter.file());
    if (!status.ok()) {
      return status;
    }
  }
  if (!iter.status().ok()) {
    return iter.status();
  }
  return DeleteDir(parent);
}

}  // namespace detail

struct DirectoryIterator::Rep {
  DIR* dir;
  struct dirent* entry;
};

DirectoryIterator::DirectoryIterator(
    const firebase::firestore::util::Path& path)
    : parent_(path), rep_(absl::make_unique<DirectoryIterator::Rep>()) {
  rep_->dir = ::opendir(parent_.c_str());
  if (!rep_->dir) {
    if (errno == ENOENT) {
      status_ = Status::OK();
    } else {
      status_ = Status::FromErrno(
          errno,
          StringFormat("Could not open directory %s", parent_.ToUtf8String()));
    }
  } else {
    status_ = Status::OK();
  }
  if (status_.ok()) {
    Advance();
  }
}

DirectoryIterator::~DirectoryIterator() {
  if (rep_->dir) {
    if (::closedir(rep_->dir) != 0) {
      HARD_FAIL("Could not close directory %s", parent_.ToUtf8String());
    }
  }
}

void DirectoryIterator::Advance() {
  HARD_ASSERT(status_.ok(), "Advancing an errored iterator");
  errno = 0;
  rep_->entry = ::readdir(rep_->dir);
  if (!rep_->entry) {
    if (errno != 0) {
      status_ = Status::FromErrno(
          errno, StringFormat("Could not read %s", parent_.ToUtf8String()));
    }
  } else if (status_.ok()) {
    // Skip self- and parent-pointer
    if (::strcmp(".", rep_->entry->d_name) == 0 ||
        ::strcmp("..", rep_->entry->d_name) == 0) {
      Advance();
    }
  }
}

void DirectoryIterator::Next() {
  HARD_ASSERT(Valid(), "Next() called on invalid iterator");
  Advance();
}

bool DirectoryIterator::Valid() {
  return status_.ok() && rep_->entry != nullptr;
}

Path DirectoryIterator::file() {
  HARD_ASSERT(Valid(), "file() called on invalid iterator");
  Path child =
      parent_.AppendUtf8(rep_->entry->d_name, strlen(rep_->entry->d_name));
  return child;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
