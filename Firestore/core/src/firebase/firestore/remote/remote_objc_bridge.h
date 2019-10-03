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

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <memory>
#include <string>
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
#include "absl/types/optional.h"
#include "grpcpp/support/byte_buffer.h"

#import "Firestore/Protos/objc/google/firestore/v1/Firestore.pbobjc.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"

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

StatusOr<ByteString> ToByteString(const grpc::ByteBuffer& buffer);

}

template <typename T>
class NanopbProto {
 public:
  explicit NanopbProto(const pb_field_t* fields) : fields_{fields} {
  }

  ~NanopbProto() {
    Serializer::FreeNanopbMessage(fields_, &proto_);
  }

  NanopbProto(const NanopbProto&) = delete;
  NanopbProto(NanopbProto&&) = default;

  NanopbProto& operator=(const NanopbProto&) = delete;
  NanopbProto& operator=(NanopbProto&&) = default;

  const T& get() const {
    return proto_;
  }

  static StatusOr<NanopbProto> Parse(const pb_field_t* fields,
                                     const grpc::ByteBuffer& message);

 private:
  const pb_field_t* fields_ = nullptr;
  T proto_{};
};

/**
 * A C++ bridge to `FSTSerializerBeta` that allows creating
 * `GCFSListenRequest`s and parsing `GCFSListenResponse`s.
 */
class WatchStreamSerializer {
 public:
  explicit WatchStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  GCFSListenRequest* CreateWatchRequest(const local::QueryData& query) const;
  GCFSListenRequest* CreateUnwatchRequest(model::TargetId target_id) const;
  static grpc::ByteBuffer ToByteBuffer(GCFSListenRequest* request);

  /**
   * If parsing fails, will return nil and write information on the error to
   * `out_status`. Otherwise, returns the parsed proto and sets `out_status` to
   * ok.
   */
  GCFSListenResponse* ParseResponse(const grpc::ByteBuffer& message,
                                    util::Status* out_status) const;
  std::unique_ptr<WatchChange> ToWatchChange(GCFSListenResponse* proto) const;
  model::SnapshotVersion ToSnapshotVersion(GCFSListenResponse* proto) const;

  /** Creates a pretty-printed description of the proto for debugging. */
  static NSString* Describe(GCFSListenRequest* request);
  static NSString* Describe(GCFSListenResponse* request);

 private:
  FSTSerializerBeta* serializer_;
};

/**
 * A C++ bridge to `FSTSerializerBeta` that allows creating
 * `GCFSWriteRequest`s and parsing `GCFSWriteResponse`s.
 */
class WriteStreamSerializer {
 public:
  explicit WriteStreamSerializer(FSTSerializerBeta* serializer);

  void UpdateLastStreamToken(GCFSWriteResponse* proto);
  void SetLastStreamToken(const nanopb::ByteString& token) {
    last_stream_token_ = token;
  }
  nanopb::ByteString GetLastStreamToken() const {
    return last_stream_token_;
  }

  google_firestore_v1_WriteRequest CreateHandshake() const;
  google_firestore_v1_WriteRequest CreateWriteMutationsRequest(
      const std::vector<model::Mutation>& mutations) const;
  google_firestore_v1_WriteRequest CreateEmptyMutationsList() {
    return CreateWriteMutationsRequest({});
  }

  static grpc::ByteBuffer ToByteBuffer(
      google_firestore_v1_WriteRequest&& request);

  util::StatusOr<google_firestore_v1_WriteResponse> ParseResponse(
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
  FSTSerializerBeta* serializer_;
  Serializer cc_serializer_;
  nanopb::ByteString last_stream_token_;
};

/**
 * A C++ bridge to `FSTSerializerBeta` that allows creating
 * `GCFSCommitRequest`s and `GCFSBatchGetDocumentsRequest`s and handling
 * `GCFSBatchGetDocumentsResponse`s.
 */
class DatastoreSerializer {
 public:
  explicit DatastoreSerializer(const core::DatabaseInfo& database_info);

  GCFSCommitRequest* CreateCommitRequest(
      const std::vector<model::Mutation>& mutations) const;
  static grpc::ByteBuffer ToByteBuffer(GCFSCommitRequest* request);

  GCFSBatchGetDocumentsRequest* CreateLookupRequest(
      const std::vector<model::DocumentKey>& keys) const;
  static grpc::ByteBuffer ToByteBuffer(GCFSBatchGetDocumentsRequest* request);

  /**
   * Merges results of the streaming read together. The array is sorted by the
   * document key.
   */
  std::vector<model::MaybeDocument> MergeLookupResponses(
      const std::vector<grpc::ByteBuffer>& responses,
      util::Status* out_status) const;
  model::MaybeDocument ToMaybeDocument(
      GCFSBatchGetDocumentsResponse* response) const;

  FSTSerializerBeta* GetSerializer() {
    return serializer_;
  }

 private:
  FSTSerializerBeta* serializer_;
};

static StatusOr<NanopbProto> Parse(const pb_field_t* fields,
                                   const grpc::ByteBuffer& message) {
  auto maybe_bytes = ToByteString(message);
  if (!maybe_bytes.ok()) {
    return maybe_bytes.status();
  }

  auto bytes = maybe_bytes.ValueOrDie();
  Reader reader{bytes};

  NanopbProto result;
  reader.ReadNanopbMessage(fields, &result.proto_);

  // TODO(varconst): additional error handling? Currently, `nanopb::Reader`
  // simply fails upon any error.
  return result;
}

}  // namespace bridge
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_OBJC_BRIDGE_H_
