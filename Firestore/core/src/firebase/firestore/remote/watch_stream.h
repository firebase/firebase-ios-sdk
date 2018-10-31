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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_WATCH_STREAM_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_WATCH_STREAM_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_connection.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_objc_bridge.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/strings/string_view.h"
#include "grpcpp/support/byte_buffer.h"

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * A `Stream` that implements the StreamingWatch RPC.
 *
 * Once the `WatchStream` has called the `streamDidOpen` method on the delegate,
 * any number of `WatchQuery` and `UnwatchTargetId` calls can be sent to control
 * what changes will be sent from the server for WatchChanges.
 */
class WatchStream : public Stream {
 public:
  WatchStream(util::AsyncQueue* async_queue,
              auth::CredentialsProvider* credentials_provider,
              FSTSerializerBeta* serializer,
              GrpcConnection* grpc_connection,
              id<FSTWatchStreamDelegate> delegate);

  /**
   * Registers interest in the results of the given query. If the query includes
   * a resume token, it will be included in the request. Results that affect the
   * query will be streamed back as WatchChange messages that reference the
   * target ID included in `query`.
   */
  void WatchQuery(FSTQueryData* query);

  /**
   * Unregisters interest in the results of the query associated with the given
   * `target_id`.
   */
  void UnwatchTargetId(model::TargetId target_id);

 private:
  std::unique_ptr<GrpcStream> CreateGrpcStream(
      GrpcConnection* grpc_connection, const auth::Token& token) override;
  void TearDown(GrpcStream* grpc_stream) override;

  void NotifyStreamOpen() override;
  util::Status NotifyStreamResponse(const grpc::ByteBuffer& message) override;
  void NotifyStreamClose(const util::Status& status) override;

  std::string GetDebugName() const override {
    return "WatchStream";
  }

  bridge::WatchStreamSerializer serializer_bridge_;
  bridge::WatchStreamDelegate delegate_bridge_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_WATCH_STREAM_H_
