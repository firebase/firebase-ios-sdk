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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"

#include <grpcpp/create_channel.h>
#include <utility>

#include "Firestore/Source/Remote/FSTDatastore.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace internal {

std::unique_ptr<grpc::ClientContext> ObjcBridge::CreateContext(
    const model::DatabaseId& database_id, const absl::string_view token) const {
  return [FSTDatastore createGrpcClientContextWithDatabaseID:&database_id
                                                       token:token];
}

grpc::ByteBuffer ObjcBridge::ToByteBuffer(FSTQueryData* query) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.addTarget = [serializer_ encodedTarget:query];
  request.labels = [serializer_ encodedListenRequestLabelsForQueryData:query];

  return ToByteBuffer([request data]);
}

grpc::ByteBuffer ObjcBridge::ToByteBuffer(NSData* data) const {
  const grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

NSData* ObjcBridge::ToNsData(const grpc::ByteBuffer& buffer) const {
  std::vector<grpc::Slice> slices;
  buffer.Dump(&slices);  // TODO: check return value
  if (slices.size() == 1) {
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  } else {
    // FIXME
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  }
}
}


using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::Token;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
// using firebase::firestore::model::SnapshotVersion;

WatchStream::WatchStream(std::unique_ptr<util::internal::Executor> executor,
                         const DatabaseInfo& database_info,
                         CredentialsProvider* const credentials_provider,
                         FSTSerializerBeta* serializer)
    : executor_{std::move(executor)},
      database_info_{&database_info},
      credentials_provider_{credentials_provider},
      stub_{CreateStub()},
      objc_bridge_{serializer} {
      Start();
    }

    void WatchStream::Start() {
      // TODO: on error state
      // TODO: state transition details

      state_ = State::Auth;
      // TODO: delegate?

      const bool do_force_refresh = false;
      credentials_provider_->GetToken(
          do_force_refresh, [this](util::StatusOr<Token> maybe_token) {
            Authenticate(maybe_token);
          });
    }

    // Call may be closed due to:
    // - error;
    // - idleness;
    // - network disable/reenable
    void WatchStream::Authenticate(const util::StatusOr<Token>& maybe_token) {
      if (state_ == State::Stopped) {
        // Streams can be stopped while waiting for authorization.
        return;
      }
      // TODO: state transition details
      if (!maybe_token.ok()) {
        // TODO: error handling
        return;
      }

      const absl::string_view token = [&] {
        const auto token = maybe_token.ValueOrDie();
        return token.user().is_authenticated() ? token.token()
                                               : absl::string_view{};
      }();
      context_ =
          objc_bridge_.CreateContext(database_info_->database_id(), token);
      call_ = stub_.PrepareCall(context_.get(),
                                "/google.firestore.v1beta1.Firestore/Listen",
                                &queue_);
      // TODO: if !call_
      // callback filter

      state_ = State::Open;
      // notifystreamopen
    }

    void WatchStream::WatchQuery(FSTQueryData * query) {
      // [self cancelIdleCheck];

      // FSTBufferedWriter* requestsWriter = self.requestsWriter;
      // @synchronized(requestsWriter) {
      //   [requestsWriter writeValue:data];
      // }
    }

    // Private

    grpc::GenericStub WatchStream::CreateStub() const {
      return grpc::GenericStub{grpc::CreateChannel(
          database_info_->host(),
          grpc::SslCredentials(grpc::SslCredentialsOptions()))};
    }

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
