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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_H_

#include <memory>

#include <grpcpp/support/byte_buffer.h>

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcCall;

class StreamOperation {
 public:
  StreamOperation(Stream* const stream,
                  const std::shared_ptr<GrpcCall>& call,
                  const int generation)
      : stream_{stream}, call_{call}, generation_{generation} {
  }
  virtual ~StreamOperation() {
  }

  void Execute();
  void Complete(bool ok);

 private:
  virtual void DoExecute(GrpcCall* call) = 0;
  virtual void OnCompletion(Stream* stream, bool ok) = 0;

  bool SameGeneration() const;

  Stream* stream_;
  // TODO: explain ownership
  std::shared_ptr<GrpcCall> call_;
  int generation_ = -1;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_H_
