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

#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

Status::Status(FirestoreErrorCode code, absl::string_view msg) {
  HARD_ASSERT(code != FirestoreErrorCode::Ok);
  state_ = absl::make_unique<State>();
  state_->code = code;
  state_->msg = static_cast<std::string>(msg);
}

void Status::Update(const Status& new_status) {
  if (ok()) {
    *this = new_status;
  }
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
  return *this;
}

void Status::SlowCopyFrom(const State* src) {
  if (src == nullptr) {
    state_ = nullptr;
  } else {
    state_ = absl::make_unique<State>(*src);
  }
}

const std::string& Status::empty_string() {
  static std::string* empty = new std::string;
  return *empty;
}

std::string Status::ToString() const {
  if (state_ == nullptr) {
    return "OK";
  } else {
    std::string result;
    switch (code()) {
      case FirestoreErrorCode::Cancelled:
        result = "Cancelled";
        break;
      case FirestoreErrorCode::Unknown:
        result = "Unknown";
        break;
      case FirestoreErrorCode::InvalidArgument:
        result = "Invalid argument";
        break;
      case FirestoreErrorCode::DeadlineExceeded:
        result = "Deadline exceeded";
        break;
      case FirestoreErrorCode::NotFound:
        result = "Not found";
        break;
      case FirestoreErrorCode::AlreadyExists:
        result = "Already exists";
        break;
      case FirestoreErrorCode::PermissionDenied:
        result = "Permission denied";
        break;
      case FirestoreErrorCode::Unauthenticated:
        result = "Unauthenticated";
        break;
      case FirestoreErrorCode::ResourceExhausted:
        result = "Resource exhausted";
        break;
      case FirestoreErrorCode::FailedPrecondition:
        result = "Failed precondition";
        break;
      case FirestoreErrorCode::Aborted:
        result = "Aborted";
        break;
      case FirestoreErrorCode::OutOfRange:
        result = "Out of range";
        break;
      case FirestoreErrorCode::Unimplemented:
        result = "Unimplemented";
        break;
      case FirestoreErrorCode::Internal:
        result = "Internal";
        break;
      case FirestoreErrorCode::Unavailable:
        result = "Unavailable";
        break;
      case FirestoreErrorCode::DataLoss:
        result = "Data loss";
        break;
      default:
        result = StringFormat("Unknown code(%s)", code());
        break;
    }
    result += ": ";
    result += state_->msg;
    return result;
  }
}

void Status::IgnoreError() const {
  // no-op
}

std::string StatusCheckOpHelperOutOfLine(const Status& v, const char* msg) {
  HARD_ASSERT(!v.ok());
  std::string r("Non-OK-status: ");
  r += msg;
  r += " status: ";
  r += v.ToString();
  return r;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
