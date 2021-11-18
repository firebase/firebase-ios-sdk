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
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_channel.h"

#include <memory>

#import "GRPCSwiftShim/GRPCSwiftShim-Swift.h"

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_apple.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

using firebase::firestore::util::MakeNSString;
using firebase::firestore::util::MakeString;

class ClientContextImpl {
 public:
  void AddMetadata(const std::string& meta_key, const std::string& meta_value) {
    [shim_ addMetadataWithName:MakeNSString(meta_key)
                         value:MakeNSString(meta_value)];
  }

 private:
  CallOptionsShim* shim_;
};

ClientContext::ClientContext() : impl_(new ClientContextImpl()) {
}
ClientContext::~ClientContext() {
  delete impl_;
}
void ClientContext::AddMetadata(const std::string& meta_key,
                                const std::string& meta_value) {
  impl_->AddMetadata(meta_key, meta_value);
}

grpc_connectivity_state Channel::GetState(bool try_to_connect) {
  return GRPC_CHANNEL_SHUTDOWN;
}

class ChannelImpl : public Channel {
 public:
  explicit ChannelImpl(ClientConnectionShim* shim) : shim_(shim) {
  }

  grpc_connectivity_state GetState(bool try_to_connect) {
    HARD_ASSERT(!try_to_connect, "try_to_connect should be false");
    ConnectivityStateShim state = [shim_ getConnectionState];
    switch (state) {
      case ConnectivityStateShimIdle:
        return GRPC_CHANNEL_IDLE;
      case ConnectivityStateShimReady:
        return GRPC_CHANNEL_READY;

      case ConnectivityStateShimShutdown:
        return GRPC_CHANNEL_SHUTDOWN;

      case ConnectivityStateShimConnecting:
        return GRPC_CHANNEL_CONNECTING;

      case ConnectivityStateShimTransientFailure:
        return GRPC_CHANNEL_TRANSIENT_FAILURE;

      default:
        HARD_FAIL("Impossilbe connectivity state!");
    }
  }

 private:
  ClientConnectionShim* shim_;
};

std::shared_ptr<Channel> CreateCustomChannel(const std::string& target,
                                             const std::string& certs,
                                             const ChannelArguments& args) {
  ClientConnectionShim* shim =
      [ClientConnectionShim createCustomChannelWithHost:MakeNSString(target)
                                       certiticateBytes:MakeNSString(certs)];
  return std::make_shared<ChannelImpl>(shim);
}

std::shared_ptr<Channel> CreateInsecureCustomChannel(
    const std::string& target, const ChannelArguments& args) {
  ClientConnectionShim* shim =
      [ClientConnectionShim createCustomChannelWithHost:MakeNSString(target)];
  return std::make_shared<ChannelImpl>(shim);
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
