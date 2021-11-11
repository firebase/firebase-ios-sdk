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

#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_CPP_ADAPTION_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_CPP_ADAPTION_H_

#include <map>
#include <memory>
#include <string>

#include "Firestore/core/src/util/status_fwd.h"
#include "Firestore/core/src/util/warnings.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/support/string_ref.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/grpcpp.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

using grpc_connectivity_state = grpc_connectivity_state;
using ByteBuffer = grpc::ByteBuffer;
using Status = grpc::Status;
using StatusCode = grpc::StatusCode;
using string_ref = grpc::string_ref;
using CompletionQueue = grpc::CompletionQueue;
using ClientContext = grpc::ClientContext;
using Channel = grpc::Channel;
using ChannelCredentials = grpc::ChannelCredentials;
using ChannelArguments = grpc::ChannelArguments;
using SslCredentialsOptions = grpc::SslCredentialsOptions;
using string = grpc::string;
using GenericStub = grpc::GenericStub;
using WriteOptions = grpc::WriteOptions;
using GenericClientAsyncReaderWriter = grpc::GenericClientAsyncReaderWriter;
using GenericClientAsyncResponseReader = grpc::GenericClientAsyncResponseReader;
using Slice = grpc::Slice;

static inline string Version() {
  return grpc::Version();
}

static inline std::shared_ptr<Channel> CreateCustomChannel(
    const string& target,
    const std::shared_ptr<ChannelCredentials>& creds,
    const ChannelArguments& args) {
  return ::grpc_impl::CreateCustomChannelImpl(target, creds, args);
}

static inline std::shared_ptr<ChannelCredentials> InsecureChannelCredentials() {
  return ::grpc_impl::InsecureChannelCredentials();
}

static inline std::shared_ptr<ChannelCredentials> SslCredentials(
    const SslCredentialsOptions& options) {
  return ::grpc_impl::SslCredentials(options);
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_CPP_ADAPTION_H_
