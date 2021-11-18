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
#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_CHANNEL_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_CHANNEL_H_

#include <map>
#include <memory>

#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_string_ref.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

class ClientContextImpl;

class ClientContext {
 public:
  ClientContext();
  ~ClientContext();
  void AddMetadata(const std::string& meta_key, const std::string& meta_value);
  void TryCancel() {
  }
  const std::multimap<string_ref, string_ref>& GetServerInitialMetadata()
      const {
    return map_;
  }
  void set_initial_metadata_corked(bool) {
  }

 private:
  ClientContextImpl* impl_ = nullptr;
  std::multimap<string_ref, string_ref> map_;
};

/** Connectivity state of a channel. */
typedef enum {
  /** channel is idle */
  GRPC_CHANNEL_IDLE,
  /** channel is connecting */
  GRPC_CHANNEL_CONNECTING,
  /** channel is ready for work */
  GRPC_CHANNEL_READY,
  /** channel has seen a failure but expects to recover */
  GRPC_CHANNEL_TRANSIENT_FAILURE,
  /** channel has seen a failure that it cannot recover from */
  GRPC_CHANNEL_SHUTDOWN
} grpc_connectivity_state;

class Channel {
 public:
  grpc_connectivity_state GetState(bool try_to_connect);
};

class ChannelArguments {
 public:
  void SetSslTargetNameOverride(const std::string& name);
  void SetInt(const std::string& key, int value);
};

#define GRPC_ARG_KEEPALIVE_TIME_MS "grpc.keepalive_time_ms"

std::shared_ptr<Channel> CreateCustomChannel(const std::string& target,
                                             const std::string& certs,
                                             const ChannelArguments& args);

std::shared_ptr<Channel> CreateInsecureCustomChannel(
    const std::string& target, const ChannelArguments& args);

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_CHANNEL_H_
