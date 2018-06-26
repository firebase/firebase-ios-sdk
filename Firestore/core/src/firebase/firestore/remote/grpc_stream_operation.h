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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_OPERATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_OPERATION_H_

#include <memory>

#include <grpcpp/client_context.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/support/byte_buffer.h>

#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcStreamOperation {
 public:
  virtual ~GrpcStreamOperation() {
  }

  virtual void Finalize(bool ok) = 0;
};

class GrpcStreamCallbacks {
public:
  virtual ~GrpcStreamCallbacks() {
  }

  virtual void OnStreamStart(bool ok) = 0;
  virtual void OnStreamRead(bool ok, const grpc::ByteBuffer& message) = 0;
  virtual void OnStreamWrite(bool ok) = 0;
  virtual void OnStreamFinish(util::Status status) = 0;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_OPERATION_H_
