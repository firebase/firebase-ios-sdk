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

#include "Firestore/core/src/firebase/firestore/remote/watch_stream.h"

#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using model::TargetId;
using util::AsyncQueue;
using util::TimerId;
using util::Status;

void WatchStreamListener::OnOpen() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

void WatchStreamListener::OnClose(const util::Status& status) {
  delegate_bridge_.NotifyDelegateOnStreamFinished(status);
}

void WatchStreamListener::OnChange(FSTWatchChange* change,
                          const model::SnapshotVersion& snapshot_version) {
  delegate_bridge_.NotifyDelegateOnChange(change, snapshot_version);
}

WatchStream::WatchStream(AsyncQueue* async_queue,
                         CredentialsProvider* credentials_provider,
                         FSTSerializerBeta* serializer,
                         Datastore* datastore,
                         id delegate)
    : Stream{async_queue, credentials_provider, datastore,
             TimerId::ListenStreamConnectionBackoff, TimerId::ListenStreamIdle},
      serializer_bridge_{serializer},
      listener_{absl::make_unique<WatchStreamListener>(delegate)} {
}

void WatchStream::WatchQuery(FSTQueryData* query) {
  EnsureOnQueue();

  GCFSListenRequest* request = serializer_bridge_.CreateWatchRequest(query);
  LOG_DEBUG("%s watch: %s", GetDebugDescription(),
            serializer_bridge_.Describe(request));
  Write(serializer_bridge_.ToByteBuffer(request));
}

void WatchStream::UnwatchTargetId(TargetId target_id) {
  EnsureOnQueue();

  GCFSListenRequest* request = serializer_bridge_.CreateUnwatchRequest(target_id);
  LOG_DEBUG("%s unwatch: %s", GetDebugDescription(),
            serializer_bridge_.Describe(request));
  Write(serializer_bridge_.ToByteBuffer(request));
}

std::unique_ptr<GrpcStream> WatchStream::CreateGrpcStream(
    Datastore* datastore, absl::string_view token) {
  return datastore->CreateGrpcStream(
      token, "/google.firestore.v1beta1.Firestore/Listen", this);
}

void WatchStream::FinishGrpcStream(GrpcStream* grpc_stream) {
  grpc_stream->Finish();
}

Status WatchStream::DoOnStreamRead(const grpc::ByteBuffer& message) {
  Status status;
  GCFSListenResponse* response =
      serializer_bridge_.ParseResponse(message, &status);
  if (!status.ok()) {
    return status;
  }

  LOG_DEBUG("%s response: %s", GetDebugDescription(),
            serializer_bridge_.Describe(response));

  // A successful response means the stream is healthy.
  ResetBackoff();

  listener_->OnChange(
      serializer_bridge_.ToWatchChange(response),
      serializer_bridge_.ToSnapshotVersion(response));
  return Status::OK();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
