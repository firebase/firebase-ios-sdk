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

#include "Firestore/core/src/firebase/firestore/remote/write_stream.h"

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using util::AsyncQueue;
using util::TimerId;
using util::Status;

WriteStream::WriteStream(AsyncQueue* async_queue,
                         CredentialsProvider* credentials_provider,
                         FSTSerializerBeta* serializer,
                         Datastore* datastore,
                         id delegate)
    : Stream{async_queue, credentials_provider, datastore,
             TimerId::WriteStreamConnectionBackoff, TimerId::WriteStreamIdle},
      serializer_bridge_{serializer},
      delegate_bridge_{delegate} {
}

void WriteStream::SetLastStreamToken(NSData* token) {
  serializer_bridge_.SetLastStreamToken(token);
}

NSData* WriteStream::GetLastStreamToken() const {
  return serializer_bridge_.GetLastStreamToken();
}

void WriteStream::WriteHandshake() {
  EnsureOnQueue();
  HARD_ASSERT(IsOpen(), "Not yet open");
  HARD_ASSERT(!is_handshake_complete_, "Handshake sent out of turn");

  GCFSWriteRequest* request = serializer_bridge_.CreateHandshake();
  LOG_DEBUG("%s initial request: %s", GetDebugDescription(),
            serializer_bridge_.Describe(request));
  Write(serializer_bridge_.ToByteBuffer(request));

  // TODO(dimond): Support stream resumption. We intentionally do not set the
  // stream token on the handshake, ignoring any stream token we might have.
}

void WriteStream::WriteMutations(NSArray<FSTMutation*>* mutations) {
  EnsureOnQueue();
  HARD_ASSERT(IsOpen(), "Not yet open");
  HARD_ASSERT(is_handshake_complete_, "Mutations sent out of turn");

  GCFSWriteRequest* request = serializer_bridge_.CreateRequest(mutations);
  LOG_DEBUG("%s write request: %s", GetDebugDescription(),
            serializer_bridge_.Describe(request));
  Write(serializer_bridge_.ToByteBuffer(request));
}

std::unique_ptr<GrpcStream> WriteStream::CreateGrpcStream(
    Datastore* datastore, absl::string_view token) {
  return datastore->CreateGrpcStream(
      token, "/google.firestore.v1beta1.Firestore/Write", this);
}

void WriteStream::DoOnStreamStart() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

void WriteStream::DoOnStreamFinish(const Status& status) {
  delegate_bridge_.NotifyDelegateOnStreamFinished(status);
  // Delegate's logic might depend on whether handshake was completed, so only
  // reset it after notifying.
  is_handshake_complete_ = false;
}

Status WriteStream::DoOnStreamRead(const grpc::ByteBuffer& message) {
  EnsureOnQueue();

  Status status;
  GCFSWriteResponse* response =
      serializer_bridge_.ParseResponse(message, &status);
  if (!status.ok()) {
    return status;
  }

  LOG_DEBUG("%s response: %s", GetDebugDescription(),
            serializer_bridge_.Describe(response));

  serializer_bridge_.UpdateLastStreamToken(response);

  if (!is_handshake_complete_) {
    // The first response is the handshake response
    is_handshake_complete_ = true;
    delegate_bridge_.NotifyDelegateOnHandshakeComplete();
  } else {
    // A successful first write response means the stream is healthy.
    // Note that we could consider a successful handshake healthy, however, the
    // write itself might be causing an error we want to back off from.
    ResetBackoff();

    delegate_bridge_.NotifyDelegateOnCommit(
        serializer_bridge_.ToCommitVersion(response),
        serializer_bridge_.ToMutationResults(response));
  }

  return Status::OK();
}

void WriteStream::FinishGrpcStream(GrpcStream* grpc_stream) {
  GCFSWriteRequest* request = serializer_bridge_.CreateEmptyMutationsList();
  grpc_stream->WriteAndFinish(serializer_bridge_.ToByteBuffer(request));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
