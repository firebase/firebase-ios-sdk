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

#include "Firestore/core/src/util/filesystem.h"

#if __APPLE__

#import <Foundation/Foundation.h>

#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_format.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace util {

Status Filesystem::ExcludeFromBackups(const Path& dir) {
  NSURL* dir_url = [NSURL fileURLWithPath:dir.ToNSString()];
  NSError* error = nil;
  if (![dir_url setResourceValue:@YES
                          forKey:NSURLIsExcludedFromBackupKey
                           error:&error]) {
    return Status{
        Error::kErrorInternal,
        "Failed to mark persistence directory as excluded from backups"}
        .CausedBy(Status::FromNSError(error));
  }

  return Status::OK();
}

StatusOr<Path> Filesystem::AppDataDir(absl::string_view app_name) {
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_VISION
  NSArray<NSString*>* directories = NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES);
  return Path::FromNSString(directories[0]).AppendUtf8(app_name);

#elif TARGET_OS_TV
  NSArray<NSString*>* directories = NSSearchPathForDirectoriesInDomains(
      NSCachesDirectory, NSUserDomainMask, YES);
  return Path::FromNSString(directories[0]).AppendUtf8(app_name);

#else
#error "Don't know where to store documents on this platform."
#endif
}

StatusOr<Path> Filesystem::LegacyDocumentsDir(absl::string_view app_name) {
#if TARGET_OS_IOS || TARGET_OS_VISION
  NSArray<NSString*>* directories = NSSearchPathForDirectoriesInDomains(
      NSDocumentDirectory, NSUserDomainMask, YES);
  return Path::FromNSString(directories[0]).AppendUtf8(app_name);

#elif TARGET_OS_OSX
  std::string dot_prefixed = absl::StrCat(".", app_name);
  return Path::FromNSString(NSHomeDirectory()).AppendUtf8(dot_prefixed);

#else
  return Status(Error::kErrorUnimplemented,
                "No legacy storage on this platform.");
#endif
}

Path Filesystem::TempDir() {
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

Status Filesystem::IsDirectory(const Path& path) {
  NSFileManager* file_manager = NSFileManager.defaultManager;
  NSString* ns_path_str = path.ToNSString();
  BOOL is_directory = NO;

  if (![file_manager fileExistsAtPath:ns_path_str isDirectory:&is_directory]) {
    return Status{Error::kErrorNotFound, path.ToUtf8String()};
  }

  if (!is_directory) {
    return Status{Error::kErrorFailedPrecondition,
                  StringFormat("Path %s exists but is not a directory",
                               path.ToUtf8String())};
  }

  return Status::OK();
}

StatusOr<int64_t> Filesystem::FileSize(const Path& path) {
  NSFileManager* file_manager = NSFileManager.defaultManager;
  NSString* ns_path_str = path.ToNSString();
  NSError* error = nil;

  NSDictionary* attributes = [file_manager attributesOfItemAtPath:ns_path_str
                                                            error:&error];

  if (attributes == nil) {
    if ([error.domain isEqualToString:NSCocoaErrorDomain]) {
      switch (error.code) {
        case NSFileReadNoSuchFileError:
        case NSFileNoSuchFileError:
          return Status{Error::kErrorNotFound, path.ToUtf8String()}.CausedBy(
              Status::FromNSError(error));
      }
    }

    return Status{Error::kErrorInternal,
                  StringFormat("attributesOfItemAtPath failed for %s",
                               path.ToUtf8String())}
        .CausedBy(Status::FromNSError(error));
  }

  NSNumber* fileSizeNumber = [attributes objectForKey:NSFileSize];

  // Use brace initialization of the in64_t return value so that compilation
  // will fail if the conversion from long long is narrowing.
  return {[fileSizeNumber longLongValue]};
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // __APPLE__
