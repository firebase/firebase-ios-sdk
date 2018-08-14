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
  DIR* dir = ::opendir(parent.c_str());
  if (!dir) {
    if (errno == ENOENT) {
      return Status::OK();
    }

    return Status::FromErrno(errno, StringFormat("Could not read directory %s",
                                                 parent.ToUtf8String()));
  }

  Status result;
  while (result.ok()) {
    errno = 0;
    struct dirent* entry = ::readdir(dir);
    if (!entry) {
      if (errno != 0) {
        result = Status::FromErrno(
            errno,
            StringFormat("Could not read directory %s", parent.ToUtf8String()));
      }
      break;
    }

    if (::strcmp(".", entry->d_name) == 0 ||
        ::strcmp("..", entry->d_name) == 0) {
      continue;
    }

    Path child = parent.AppendUtf8(entry->d_name, strlen(entry->d_name));
    result = RecursivelyDelete(child);
  }

  if (::closedir(dir)) {
    result.Update(Status::FromErrno(
        errno,
        StringFormat("Could not close directory %s", parent.ToUtf8String())));
  }

  if (result.ok()) {
    result = DeleteDir(parent);
  }
  return result;
}

}  // namespace detail
}  // namespace util
}  // namespace firestore
}  // namespace firebase
