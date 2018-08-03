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

#include "Firestore/core/src/firebase/firestore/util/status.h"

#if defined(_WIN32)

#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "Firestore/core/src/firebase/firestore/util/string_win.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Returns the Canonical error code for the given Windows API error code as
 * obtained from GetLastError().
 */
static FirestoreErrorCode CodeForLastError(DWORD error) {
  switch (error) {
    case ERROR_SUCCESS:
      return FirestoreErrorCode::Ok;

      // return FirestoreErrorCode::Internal;

    case ERROR_INVALID_FUNCTION:
    case ERROR_INVALID_HANDLE:
    case ERROR_INVALID_NAME:
      return FirestoreErrorCode::InvalidArgument;

      // return FirestoreErrorCode::DeadlineExceeded;

    case ERROR_FILE_NOT_FOUND:
    case ERROR_PATH_NOT_FOUND:
    case ERROR_INVALID_DRIVE:
    case ERROR_BAD_NETPATH:
    case ERROR_DEV_NOT_EXIST:
      return FirestoreErrorCode::NotFound;

    case ERROR_FILE_EXISTS:
    case ERROR_ALREADY_EXISTS:
      return FirestoreErrorCode::AlreadyExists;

    case ERROR_ACCESS_DENIED:
    case ERROR_INVALID_ACCESS:
    case ERROR_SHARING_VIOLATION:
    case ERROR_WRITE_PROTECT:
    case ERROR_LOCK_VIOLATION:
      return FirestoreErrorCode::PermissionDenied;

      // return FirestoreErrorCode::FailedPrecondition;

    case ERROR_TOO_MANY_OPEN_FILES:
    case ERROR_NOT_ENOUGH_MEMORY:
    case ERROR_OUTOFMEMORY:
    case ERROR_NO_MORE_FILES:
    case ERROR_DISK_FULL:
    case ERROR_HANDLE_DISK_FULL:
      return FirestoreErrorCode::ResourceExhausted;

      // return FirestoreErrorCode::OutOfRange;

    case ERROR_CALL_NOT_IMPLEMENTED:
      return FirestoreErrorCode::Unimplemented;

    case ERROR_NOT_READY:
      return FirestoreErrorCode::Unavailable;

      // return FirestoreErrorCode::Aborted;

      // return FirestoreErrorCode::Cancelled;

    default:
      return FirestoreErrorCode::Unknown;
  }
}

Status Status::FromLastError(DWORD error, absl::string_view msg) {
  if (error == ERROR_SUCCESS) {
    return Status::OK();
  }

  FirestoreErrorCode canonical_code = CodeForLastError(error);
  std::string error_text = LastErrorMessage(error);
  return Status{canonical_code, util::StringFormat("%s (error %s: %s)", msg,
                                                   error, error_text)};
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // defined(_WIN32)
