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
#ifndef FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_MISC_H_
#define FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_MISC_H_

#include <map>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_status.h"
#include "Firestore/core/src/remote/grpc_adapt/grpc_swift_string_ref.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace grpc_adapt {

class ClientContext {
 public:
  ClientContext();
  ~ClientContext();

  void AddMetadata(const std::string& meta_key, const std::string& meta_value);
  void TryCancel();
  const std::multimap<string_ref, string_ref>& GetServerInitialMetadata() const;
  void set_initial_metadata_corked(bool);
};

class Slice {
 public:
  Slice(const void* buf, size_t len);
  Slice(const std::string& s);
  /// Byte size.
  size_t size() const;

  /// Raw pointer to the beginning (first element) of the slice.
  const uint8_t* begin() const;
};

class ByteBuffer final {
 public:
  /// Constuct an empty buffer.
  ByteBuffer();
  ByteBuffer(const Slice* slices, size_t nslices);

  /// Buffer size in bytes.
  size_t Length() const;
  /// Dump (read) the buffer contents into \a slices.
  Status Dump(std::vector<Slice>* slices) const;
};

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

class ChannelCredentials {};

struct SslCredentialsOptions {
  /// The buffer containing the PEM encoding of the server root certificates. If
  /// this parameter is empty, the default roots will be used.  The default
  /// roots can be overridden using the \a GRPC_DEFAULT_SSL_ROOTS_FILE_PATH
  /// environment variable pointing to a file on the file system containing the
  /// roots.
  std::string pem_root_certs;

  /// The buffer containing the PEM encoding of the client's private key. This
  /// parameter can be empty if the client does not have a private key.
  std::string pem_private_key;

  /// The buffer containing the PEM encoding of the client's certificate chain.
  /// This parameter can be empty if the client does not have a certificate
  /// chain.
  std::string pem_cert_chain;
};

class GrpcLibraryCodegen {};

#define GRPC_ARG_KEEPALIVE_TIME_MS "grpc.keepalive_time_ms"

static std::shared_ptr<ChannelCredentials> SslCredentials(
    const SslCredentialsOptions& options) {
  (void)options;
  return nullptr;
}

static std::string Version() {
  return "";
}

static std::shared_ptr<Channel> CreateCustomChannel(
    const std::string& target,
    const std::shared_ptr<ChannelCredentials>& creds,
    const ChannelArguments& args) {
  (void)target;
  (void)creds;
  (void)args;
  return nullptr;
}

static std::shared_ptr<ChannelCredentials> InsecureChannelCredentials() {
  return nullptr;
}

}  // namespace grpc_adapt
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_GRPC_ADAPT_GRPC_SWIFT_MISC_H_
