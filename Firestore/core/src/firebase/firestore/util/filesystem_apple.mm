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

#import <Foundation/Foundation.h>

#include <sys/stat.h>

#include <cerrno>

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace util {

Status IsDirectory(const Path& path) {
  struct stat buffer {};
  if (::stat(path.c_str(), &buffer)) {
    return Status::FromErrno(
        errno, StringFormat("Path %s is not a directory", path.ToUtf8String()));
  }

  if (!S_ISDIR(buffer.st_mode)) {
    return Status{FirestoreErrorCode::FailedPrecondition,
                  StringFormat("Path %s exists but is not a directory",
                               path.ToUtf8String())};
  }

  return Status::OK();
}

Status RecursivelyCreateDir(const Path& path) {
  NSString* ns_path = path.ToNSString();

  NSError* error = nil;
  if (![[NSFileManager defaultManager] createDirectoryAtPath:ns_path
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error]) {
    return Status::FromNSError(error);
  }
  return Status::OK();
}

Status RecursivelyDelete(const Path& path) {
  NSString* ns_path = path.ToNSString();
  NSError* error = nil;
  if (![[NSFileManager defaultManager] removeItemAtPath:ns_path error:&error]) {
    Status status = Status::FromNSError(error);
    if (status.code() == FirestoreErrorCode::NotFound) {
      // Successful by definition
      return Status::OK();
    }

    return status;
  }
  return Status::OK();
}

Path TempDir() {
  const char* env_tmpdir = getenv("TMPDIR");
  if (env_tmpdir) {
    return Path::FromUtf8(env_tmpdir);
  }

  NSString* ns_tmpdir = NSTemporaryDirectory();
  if (ns_tmpdir) {
    return Path::FromNSString(ns_tmpdir);
  }

  return Path::FromUtf8("/tmp");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
