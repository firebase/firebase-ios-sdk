/*
 * Copyright 2015, 2018 Google
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

#include "Firestore/core/src/firebase/firestore/util/status.h"

#include <cerrno>

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace util {

Status Status::FromNSError(NSError* error) {
  NSError* original = error;

  while (error) {
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
      return FromErrno(static_cast<int>(error.code),
                       MakeStringView(original.localizedDescription));
    }

    error = error.userInfo[NSUnderlyingErrorKey];
  }

  return Status{FirestoreErrorCode::Unknown,
                StringFormat("Unknown error: %s", original)};
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
