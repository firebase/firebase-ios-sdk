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

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

#if defined(__APPLE__)

namespace firebase {
namespace firestore {
namespace local {

using util::Path;
using util::Status;

Status LevelDbPersistence::ExcludeFromBackups(const Path& dir) {
  NSURL* dir_url = [NSURL fileURLWithPath:dir.ToNSString()];
  NSError* error = nil;
  if (![dir_url setResourceValue:@YES
                          forKey:NSURLIsExcludedFromBackupKey
                           error:&error]) {
    return Status{
        Error::Internal,
        "Failed to mark persistence directory as excluded from backups"}
        .CausedBy(Status::FromNSError(error));
  }

  return Status::OK();
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // __APPLE__
