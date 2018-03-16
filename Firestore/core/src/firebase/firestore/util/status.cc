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

namespace firebase {
namespace firestore {
namespace util {

Status::Status(FirestoreErrorCode code, absl::string_view msg) {
  FIREBASE_ASSERT(code != FirestoreErrorCode::Ok);
  state_ = std::unique_ptr<State>(new State);
  state_->code = code;
  state_->msg = std::string(msg.data(), msg.data() + msg.size());
}

void Status::Update(const Status& new_status) {
  if (ok()) {
    *this = new_status;
  }
}

void Status::SlowCopyFrom(const State* src) {
  if (src == nullptr) {
    state_ = nullptr;
  } else {
    state_ = std::unique_ptr<State>(new State(*src));
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
    char tmp[30];
    const char* type;
    switch (code()) {
      case FirestoreErrorCode::Cancelled:
        type = "Cancelled";
        break;
      case FirestoreErrorCode::Unknown:
        type = "Unknown";
        break;
      case FirestoreErrorCode::InvalidArgument:
        type = "Invalid argument";
        break;
      case FirestoreErrorCode::DeadlineExceeded:
        type = "Deadline exceeded";
        break;
      case FirestoreErrorCode::NotFound:
        type = "Not found";
        break;
      case FirestoreErrorCode::AlreadyExists:
        type = "Already exists";
        break;
      case FirestoreErrorCode::PermissionDenied:
        type = "Permission denied";
        break;
      case FirestoreErrorCode::Unauthenticated:
        type = "Unauthenticated";
        break;
      case FirestoreErrorCode::ResourceExhausted:
        type = "Resource exhausted";
        break;
      case FirestoreErrorCode::FailedPrecondition:
        type = "Failed precondition";
        break;
      case FirestoreErrorCode::Aborted:
        type = "Aborted";
        break;
      case FirestoreErrorCode::OutOfRange:
        type = "Out of range";
        break;
      case FirestoreErrorCode::Unimplemented:
        type = "Unimplemented";
        break;
      case FirestoreErrorCode::Internal:
        type = "Internal";
        break;
      case FirestoreErrorCode::Unavailable:
        type = "Unavailable";
        break;
      case FirestoreErrorCode::DataLoss:
        type = "Data loss";
        break;
      default:
        snprintf(tmp, sizeof(tmp), "Unknown code(%d)",
                 static_cast<int>(code()));
        type = tmp;
        break;
    }
    std::string result(type);
    result += ": ";
    result += state_->msg;
    return result;
  }
}

void Status::IgnoreError() const {
  // no-op
}

std::ostream& operator<<(std::ostream& os, const Status& x) {
  os << x.ToString();
  return os;
}

std::string StatusCheckOpHelperOutOfLine(const Status& v, const char* msg) {
  FIREBASE_ASSERT(!v.ok());
  std::string r("Non-OK-status: ");
  r += msg;
  r += " status: ";
  r += v.ToString();
  return r;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
