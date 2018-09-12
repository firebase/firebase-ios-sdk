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

WatchStream::WatchStream(AsyncQueue* async_queue,
                         CredentialsProvider* credentials_provider,
                         FSTSerializerBeta* serializer,
                         Datastore* datastore,
                         id<FSTWatchStreamDelegate> delegate)
    : Stream{async_queue, credentials_provider, datastore,
             TimerId::ListenStreamConnectionBackoff, TimerId::ListenStreamIdle},
      serializer_bridge_{serializer},
      delegate_bridge_{delegate} {
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

  GCFSListenRequest* request =
      serializer_bridge_.CreateUnwatchRequest(target_id);
  LOG_DEBUG("%s unwatch: %s", GetDebugDescription(),
            serializer_bridge_.Describe(request));
  Write(serializer_bridge_.ToByteBuffer(request));
}

std::unique_ptr<GrpcStream> WatchStream::CreateGrpcStream(
    Datastore* datastore, absl::string_view token) {
  return datastore->CreateGrpcStream(
      token, "/google.firestore.v1beta1.Firestore/Listen", this);
}

void WatchStream::TearDown(GrpcStream* grpc_stream) {
  grpc_stream->Finish();
}

void WatchStream::NotifyStreamOpen() {
  delegate_bridge_.NotifyDelegateOnOpen();
}

Status WatchStream::NotifyStreamResponse(const grpc::ByteBuffer& message) {
  Status status;
  GCFSListenResponse* response =
      serializer_bridge_.ParseResponse(message, &status);
  if (!status.ok()) {
    return status;
  }

  LOG_DEBUG("%s response: %s", GetDebugDescription(),
            serializer_bridge_.Describe(response));

  // A successful response means the stream is healthy.
  backoff_.Reset();

  delegate_bridge_.NotifyDelegateOnChange(
      serializer_bridge_.ToWatchChange(response),
      serializer_bridge_.ToSnapshotVersion(response));
  return Status::OK();
}

void WatchStream::NotifyStreamClose(const Status& status) {
  delegate_bridge_.NotifyDelegateOnClose(status);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
