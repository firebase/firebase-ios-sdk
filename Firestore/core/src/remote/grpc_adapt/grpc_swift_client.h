/*
 * Copyright 2021 Google LLC
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
#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_CLIENT_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_CLIENT_H_

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_channel.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_misc.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_status.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_string_ref.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

class WriteOptions {
 public:
  WriteOptions();
  WriteOptions(const WriteOptions& other);
  WriteOptions& set_last_message();
  /// Default assignment operator
  WriteOptions& operator=(const WriteOptions& other) = default;
};

class GenericClientAsyncReaderWriter {
 public:
  void StartCall(void* tag);
  void Read(ByteBuffer* msg, void* tag);
  void Write(const ByteBuffer& msg, void* tag);
  void Write(const ByteBuffer& msg, WriteOptions options, void* tag);
  void Finish(Status* status, void* tag);
  void WriteLast(const ByteBuffer& msg, WriteOptions options, void* tag);
};

class GenericClientAsyncResponseReader {
 public:
  void StartCall();
  void Finish(ByteBuffer* msg, Status* status, void* tag);
};

class CompletionQueue {
 public:
  bool Next(void** tag, bool* ok);
  void Shutdown();
};

class GenericStub {
 public:
  explicit GenericStub(std::shared_ptr<Channel> channel);
  std::unique_ptr<GenericClientAsyncReaderWriter> PrepareCall(
      ClientContext* context, const std::string& method, CompletionQueue* cq);

  /// Setup a unary call to a named method \a method using \a context, and don't
  /// start it. Let it be started explicitly with StartCall.
  /// The return value only indicates whether or not registration of the call
  /// succeeded (i.e. the call won't proceed if the return value is nullptr).
  std::unique_ptr<GenericClientAsyncResponseReader> PrepareUnaryCall(
      ClientContext* context,
      const std::string& method,
      const ByteBuffer& request,
      CompletionQueue* cq);
};

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_CLIENT_H_
