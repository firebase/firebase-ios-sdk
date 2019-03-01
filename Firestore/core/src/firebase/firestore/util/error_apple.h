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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ERROR_APPLE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ERROR_APPLE_H_

// Everything in this header exists for compatibility with Objective-C.
#if __OBJC__

#import <Foundation/Foundation.h>

#import <FirebaseFirestore/FIRFirestoreErrors.h>  // for FIRFirestoreErrorDomain

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace util {

// Translates a set of error_code and error_msg to an NSError.
inline NSError* MakeNSError(const int64_t error_code,
                            const absl::string_view error_msg) {
  if (error_code == FirestoreErrorCode::Ok) {
    return nil;
  }
  return [NSError
      errorWithDomain:FIRFirestoreErrorDomain
                 code:static_cast<NSInteger>(error_code)
             userInfo:@{NSLocalizedDescriptionKey : WrapNSString(error_msg)}];
}

inline NSError* MakeNSError(const util::Status& status) {
  return MakeNSError(status.code(), status.error_message());
}

inline Status MakeStatus(NSError* error) {
  if (!error) {
    return Status::OK();
  }

  HARD_ASSERT(error.domain == FIRFirestoreErrorDomain,
              "Can only translate a Firestore error to a status");
  auto error_code = static_cast<int>(error.code);
  HARD_ASSERT(error_code >= FirestoreErrorCode::Cancelled &&
                  error_code <= FirestoreErrorCode::Unauthenticated,
              "Unknown error code");
  return Status{static_cast<FirestoreErrorCode>(error_code),
                MakeString(error.localizedDescription)};
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // __OBJC__

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_ERROR_APPLE_H_
