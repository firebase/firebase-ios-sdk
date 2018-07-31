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

namespace firebase {
namespace firestore {
namespace util {

bool Exists(const Path& path, bool* is_directory) {
  NSString* ns_path = path.ToNSString();

  BOOL is_directory_native;
  if ([[NSFileManager defaultManager] fileExistsAtPath:ns_path
                                           isDirectory:&is_directory_native]) {
    if (is_directory) {
      *is_directory = is_directory_native;
    }
    return true;
  }

  return false;
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
    if (!status.ok() && status.code() == FirestoreErrorCode::NotFound) {
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
