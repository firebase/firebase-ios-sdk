// TODO(rsgowman): how should the copyright be adapted?
// Protocol Buffers - Google's data interchange format
// Copyright 2008 Google Inc.  All rights reserved.
// https://developers.google.com/protocol-buffers/
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//     * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#include "Firestore/core/src/firebase/firestore/util/status.h"

#include <ostream>

namespace firebase {
namespace firestore {
namespace util {

namespace {
inline std::string CodeEnumToString(FirestoreErrorCode code) {
  switch (code) {
    case Ok:
      return "OK";
    case Cancelled:
      return "CANCELLED";
    case Unknown:
      return "UNKNOWN";
    case InvalidArgument:
      return "INVALID_ARGUMENT";
    case DeadlineExceeded:
      return "DEADLINE_EXCEEDED";
    case NotFound:
      return "NOT_FOUND";
    case AlreadyExists:
      return "ALREADY_EXISTS";
    case PermissionDenied:
      return "PERMISSION_DENIED";
    case ResourceExhausted:
      return "RESOURCE_EXHAUSTED";
    case FailedPrecondition:
      return "FAILED_PRECONDITION";
    case Aborted:
      return "ABORTED";
    case OutOfRange:
      return "OUT_OF_RANGE";
    case Unimplemented:
      return "UNIMPLEMENTED";
    case Internal:
      return "INTERNAL";
    case Unavailable:
      return "UNAVAILABLE";
    case DataLoss:
      return "DATA_LOSS";
    case Unauthenticated:
      return "UNAUTHENTICATED";
  }

  // No default clause, clang will abort if a code is missing from
  // above switch.
  return "UNKNOWN";
}
}  // namespace

const Status Status::OK = Status();
const Status Status::CANCELLED = Status(FirestoreErrorCode::Cancelled, "");
const Status Status::UNKNOWN = Status(FirestoreErrorCode::Unknown, "");

Status::Status() : error_code_(FirestoreErrorCode::Ok) {
}

Status::Status(FirestoreErrorCode error_code, absl::string_view error_message)
    : error_code_(error_code) {
  if (error_code != FirestoreErrorCode::Ok) {
    error_message_ = std::string(error_message.data(),
                                 error_message.data() + error_message.size());
  }
}

Status::Status(const Status& other)
    : error_code_(other.error_code_), error_message_(other.error_message_) {
}

Status& Status::operator=(const Status& other) {
  error_code_ = other.error_code_;
  error_message_ = other.error_message_;
  return *this;
}

bool Status::operator==(const Status& x) const {
  return error_code_ == x.error_code_ && error_message_ == x.error_message_;
}

std::string Status::ToString() const {
  if (error_code_ == FirestoreErrorCode::Ok) {
    return "OK";
  } else {
    if (error_message_.empty()) {
      return CodeEnumToString(error_code_);
    } else {
      return CodeEnumToString(error_code_) + ":" + error_message_;
    }
  }
}

std::ostream& operator<<(std::ostream& os, const Status& x) {
  os << x.ToString();
  return os;
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
