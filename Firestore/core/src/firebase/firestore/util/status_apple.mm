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

#if defined(__APPLE__)

#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

class UnderlyingNSError : public PlatformError {
 public:
  explicit UnderlyingNSError(NSError* error) : error_(error) {
  }

  ~UnderlyingNSError() {
  }

  static std::unique_ptr<UnderlyingNSError> Create(NSError* error) {
    return absl::make_unique<UnderlyingNSError>(error);
  }

  static NSError* Recover(const std::unique_ptr<PlatformError>& wrapped) {
    if (wrapped == nullptr) {
      return nil;
    }

    return static_cast<UnderlyingNSError*>(wrapped.get())->error();
  }

  std::unique_ptr<PlatformError> Copy() override {
    return absl::make_unique<UnderlyingNSError>(error_);
  }

  NSError* error() const {
    return error_;
  }

 private:
  NSError* error_;
};

Status Status::FromNSError(NSError* error) {
  if (!error) {
    return Status::OK();
  }

  auto original = UnderlyingNSError::Create(error);

  while (error) {
    if ([error.domain isEqualToString:NSPOSIXErrorDomain]) {
      return FromErrno(static_cast<int>(error.code),
                       MakeString(original->error().localizedDescription))
          .WithPlatformError(std::move(original));
    }

    error = error.userInfo[NSUnderlyingErrorKey];
  }

  return Status{FirestoreErrorCode::Unknown,
                StringFormat("Unknown error: %s", original->error())}
      .WithPlatformError(std::move(original));
}

NSError* Status::ToNSError() const {
  if (ok()) return nil;

  NSError* error = UnderlyingNSError::Recover(state_->wrapped);
  if (error) return error;

  return MakeNSError(code(), error_message());
}

Status& Status::CausedBy(const Status& cause) {
  if (cause.ok() || this == &cause) {
    return *this;
  }

  if (ok()) {
    *this = cause;
    return *this;
  }

  absl::StrAppend(&state_->msg, ": ", cause.error_message());

  // If this Status has no wrapped NSError but the cause does, create an NSError
  // for this Status ahead of time to preserve the causal chain that Status
  // doesn't otherwise support.
  NSError* cause_nserror = UnderlyingNSError::Recover(cause.state_->wrapped);
  if (state_->wrapped == nullptr && cause_nserror) {
    NSError* chain = MakeNSError(code(), error_message(), cause_nserror);
    state_->wrapped = UnderlyingNSError::Create(chain);
  }

  return *this;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // defined(__APPLE__)
