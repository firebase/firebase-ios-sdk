/*
 * Copyright 2026 Google LLC
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

#include "Firestore/core/test/unit/remote/tls_loopback_server.h"

#if !defined(__APPLE__)

#include <chrono>
#include <vector>

#include "Firestore/core/src/util/hard_assert.h"
#include "absl/strings/str_cat.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpc/impl/channel_arg_names.h"
#include "grpcpp/client_context.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/security/server_credentials.h"
#include "grpcpp/server_builder.h"
#include "grpcpp/support/byte_buffer.h"
#include "grpcpp/support/channel_arguments.h"
#include "grpcpp/support/slice.h"
SUPPRESS_END()

namespace firebase {
namespace firestore {
namespace remote {
namespace tls_testing {
namespace {

enum class Step { kRequest, kRead, kWriteAndFinish };

struct CallState {
  grpc::GenericServerContext ctx;
  grpc::GenericServerAsyncReaderWriter stream{&ctx};
  grpc::ByteBuffer request;
  Step step = Step::kRequest;
};

std::string ReadByteBuffer(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  grpc::Status dump_status = buffer.Dump(&slices);
  HARD_ASSERT(dump_status.ok(), "ByteBuffer::Dump failed");
  std::string out;
  for (const grpc::Slice& slice : slices) {
    out.append(reinterpret_cast<const char*>(slice.begin()), slice.size());
  }
  return out;
}

}  // namespace

TlsLoopbackServer::TlsLoopbackServer(const std::string& private_key_pem,
                                     const std::string& cert_chain_pem) {
  grpc::SslServerCredentialsOptions ssl_options;
  ssl_options.pem_key_cert_pairs.push_back({private_key_pem, cert_chain_pem});

  grpc::ServerBuilder builder;
  builder.AddListeningPort("127.0.0.1:0",
                           grpc::SslServerCredentials(ssl_options), &port_);
  builder.RegisterAsyncGenericService(&generic_service_);
  cq_ = builder.AddCompletionQueue();
  server_ = builder.BuildAndStart();

  if (server_ != nullptr && port_ > 0) {
    server_thread_ = std::thread([this] { ServeLoop(); });
  }
}

TlsLoopbackServer::~TlsLoopbackServer() {
  if (server_ != nullptr) {
    server_->Shutdown(std::chrono::system_clock::now());
  }
  {
    std::lock_guard<std::mutex> lock(mu_);
    shutting_down_ = true;
    if (cq_ != nullptr) {
      cq_->Shutdown();
    }
  }
  if (server_thread_.joinable()) {
    server_thread_.join();
  } else if (cq_ != nullptr) {
    // The serve loop never started; drain the queue ourselves.
    void* tag = nullptr;
    bool ok = false;
    while (cq_->Next(&tag, &ok)) {
    }
  }
}

std::string TlsLoopbackServer::target() const {
  return absl::StrCat("127.0.0.1:", port_);
}

void TlsLoopbackServer::SpawnCall() {
  std::lock_guard<std::mutex> lock(mu_);
  if (shutting_down_) {
    return;
  }
  auto* state = new CallState();
  generic_service_.RequestCall(&state->ctx, &state->stream, cq_.get(),
                               cq_.get(), state);
}

void TlsLoopbackServer::ServeLoop() {
  SpawnCall();

  void* tag = nullptr;
  bool ok = false;
  while (cq_->Next(&tag, &ok)) {
    auto* state = static_cast<CallState*>(tag);
    if (!ok) {
      delete state;
      continue;
    }

    switch (state->step) {
      case Step::kRequest: {
        SpawnCall();
        std::lock_guard<std::mutex> lock(mu_);
        if (shutting_down_) {
          delete state;
          break;
        }
        state->step = Step::kRead;
        state->stream.Read(&state->request, state);
        break;
      }
      case Step::kRead: {
        std::lock_guard<std::mutex> lock(mu_);
        if (shutting_down_) {
          delete state;
          break;
        }
        state->step = Step::kWriteAndFinish;
        state->stream.WriteAndFinish(state->request, grpc::WriteOptions{},
                                     grpc::Status::OK, state);
        break;
      }
      case Step::kWriteAndFinish:
        delete state;
        break;
    }
  }
}

std::shared_ptr<grpc::Channel> CreateLoopbackChannel(
    const TlsLoopbackServer& server,
    const std::shared_ptr<grpc::ChannelCredentials>& credentials,
    const std::string& tls_target_name) {
  grpc::ChannelArguments args;
  args.SetSslTargetNameOverride(tls_target_name);
  // Each test must perform its own handshake rather than reuse a subchannel
  // (and its already-verified connection) from an earlier test.
  args.SetInt(GRPC_ARG_USE_LOCAL_SUBCHANNEL_POOL, 1);
  return grpc::CreateCustomChannel(server.target(), credentials, args);
}

grpc::Status PerformUnaryEcho(const std::shared_ptr<grpc::Channel>& channel,
                              const std::string& payload,
                              std::string* out_response) {
  grpc::GenericStub stub(channel);
  grpc::ClientContext context;
  context.set_deadline(std::chrono::system_clock::now() +
                       std::chrono::seconds(5));
  context.set_wait_for_ready(false);

  grpc::Slice req_slice(payload);
  grpc::ByteBuffer request(&req_slice, 1);
  grpc::ByteBuffer response;
  grpc::Status status;

  grpc::CompletionQueue cq;
  std::unique_ptr<grpc::GenericClientAsyncResponseReader> call =
      stub.PrepareUnaryCall(&context, "/firestore.TlsLoopbackTest/Echo",
                            request, &cq);
  HARD_ASSERT(call != nullptr, "PrepareUnaryCall returned null");
  call->StartCall();

  void* finish_tag = reinterpret_cast<void*>(1);
  call->Finish(&response, &status, finish_tag);

  void* got_tag = nullptr;
  bool ok = false;
  HARD_ASSERT(cq.Next(&got_tag, &ok) && got_tag == finish_tag,
              "Expected unary RPC finish tag from CompletionQueue");
  cq.Shutdown();
  while (cq.Next(&got_tag, &ok)) {
  }

  if (status.ok() && out_response != nullptr) {
    *out_response = ReadByteBuffer(response);
  }
  return status;
}

}  // namespace tls_testing
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__)
