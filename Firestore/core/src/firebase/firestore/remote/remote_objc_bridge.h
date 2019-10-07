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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_OBJC_BRIDGE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_OBJC_BRIDGE_H_

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/util/status_fwd.h"
// FIXME
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "absl/types/optional.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace bridge {

bool IsLoggingEnabled();

/**
 * This file contains operations in remote/ folder that are still delegated to
 * Objective-C: proto parsing and delegates.
 *
 * The principle is that the C++ implementation can only take Objective-C
 * objects as parameters or return them, but never instantiate them or call any
 * methods on them -- if that is necessary, it's delegated to one of the bridge
 * classes. This allows easily identifying which parts of remote/ still rely on
 * not-yet-ported code.
 */

namespace internal {

util::StatusOr<nanopb::ByteString> ToByteString(const grpc::ByteBuffer& buffer);

}

template <typename T>
class NanopbProto {
 public:
  explicit NanopbProto(const pb_field_t* fields) : fields_{fields} {
  }

  ~NanopbProto() {
    if (fields_) {
      Serializer::FreeNanopbMessage(fields_, &proto_);
    }
  }

  NanopbProto(const NanopbProto&) = delete;
  NanopbProto& operator=(const NanopbProto&) = delete;

  NanopbProto(NanopbProto&& other) noexcept
      : fields_{other.fields_}, proto_{other.proto_} {
    other.fields_ = nullptr;
  }
  NanopbProto& operator=(NanopbProto&& other) noexcept {
    fields_ = other.fields_;
    proto_ = other.proto_;
    other.fields_ = nullptr;
  }

  const T& get() const {
    return proto_;
  }

  static util::StatusOr<NanopbProto> Parse(const pb_field_t* fields,
                                           const grpc::ByteBuffer& message);

 private:
  const pb_field_t* fields_ = nullptr;
  T proto_{};
};

class WatchStreamSerializer {
 public:
  explicit WatchStreamSerializer(Serializer serializer);

  google_firestore_v1_ListenRequest CreateWatchRequest(
      const local::QueryData& query) const;
  google_firestore_v1_ListenRequest CreateUnwatchRequest(
      model::TargetId target_id) const;
  static grpc::ByteBuffer ToByteBuffer(
      google_firestore_v1_ListenRequest&& request);

  util::StatusOr<NanopbProto<google_firestore_v1_ListenResponse>> ParseResponse(
      const grpc::ByteBuffer& message) const;
  std::unique_ptr<WatchChange> ToWatchChange(
      const google_firestore_v1_ListenResponse& response) const;
  model::SnapshotVersion ToSnapshotVersion(
      const google_firestore_v1_ListenResponse& response) const;

  /** Creates a pretty-printed description of the proto for debugging. */
  static std::string Describe(const google_firestore_v1_ListenRequest& request);
  static std::string Describe(
      const google_firestore_v1_ListenResponse& response);

 private:
  Serializer serializer_;
};

class WriteStreamSerializer {
 public:
  explicit WriteStreamSerializer(Serializer serializer);

  google_firestore_v1_WriteRequest CreateHandshake() const;
  google_firestore_v1_WriteRequest CreateWriteMutationsRequest(
      const std::vector<model::Mutation>& mutations,
      const nanopb::ByteString& last_stream_token) const;
  google_firestore_v1_WriteRequest CreateEmptyMutationsList(
      const nanopb::ByteString& last_stream_token) const {
    return CreateWriteMutationsRequest({}, last_stream_token);
  }

  static grpc::ByteBuffer ToByteBuffer(
      google_firestore_v1_WriteRequest&& request);

  util::StatusOr<NanopbProto<google_firestore_v1_WriteResponse>> ParseResponse(
      const grpc::ByteBuffer& message) const;
  model::SnapshotVersion ToCommitVersion(
      const google_firestore_v1_WriteResponse& proto) const;
  std::vector<model::MutationResult> ToMutationResults(
      const google_firestore_v1_WriteResponse& proto) const;

  /** Creates a pretty-printed description of the proto for debugging. */
  static std::string Describe(const google_firestore_v1_WriteRequest& request);
  static std::string Describe(
      const google_firestore_v1_WriteResponse& response);

 private:
  Serializer serializer_;
};

class DatastoreSerializer {
 public:
  explicit DatastoreSerializer(const core::DatabaseInfo& database_info);

  google_firestore_v1_CommitRequest CreateCommitRequest(
      const std::vector<model::Mutation>& mutations) const;
  static grpc::ByteBuffer ToByteBuffer(
      google_firestore_v1_CommitRequest&& request);

  google_firestore_v1_BatchGetDocumentsRequest CreateLookupRequest(
      const std::vector<model::DocumentKey>& keys) const;
  static grpc::ByteBuffer ToByteBuffer(
      google_firestore_v1_BatchGetDocumentsRequest&& request);

  /**
   * Merges results of the streaming read together. The array is sorted by the
   * document key.
   */
  util::StatusOr<std::vector<model::MaybeDocument>> MergeLookupResponses(
      const std::vector<grpc::ByteBuffer>& responses) const;
  model::MaybeDocument ToMaybeDocument(
      const google_firestore_v1_BatchGetDocumentsResponse& response) const;

  const Serializer& serializer() const {
    return serializer_;
  }

 private:
  Serializer serializer_;
};

template <typename T>
util::StatusOr<NanopbProto<T>> NanopbProto<T>::Parse(
    const pb_field_t* fields, const grpc::ByteBuffer& message) {
  auto maybe_bytes = internal::ToByteString(message);
  if (!maybe_bytes.ok()) {
    return maybe_bytes.status();
  }

  auto bytes = maybe_bytes.ValueOrDie();
  nanopb::Reader reader{bytes};

  NanopbProto result{fields};
  reader.ReadNanopbMessage(fields, &result.proto_);

  // TODO(varconst): additional error handling? Currently, `nanopb::Reader`
  // simply fails upon any error.
  util::StatusOr<NanopbProto<T>> return_value{std::move(result)};
  return return_value;
}

}  // namespace bridge
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_OBJC_BRIDGE_H_
