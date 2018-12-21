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

#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "grpcpp/support/byte_buffer.h"

#import "Firestore/Protos/objc/google/firestore/v1/Firestore.pbobjc.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"

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

/**
 * A C++ bridge to `FSTSerializerBeta` that allows creating
 * `GCFSListenRequest`s and parsing `GCFSListenResponse`s.
 */
class WatchStreamSerializer {
 public:
  explicit WatchStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  GCFSListenRequest* CreateWatchRequest(FSTQueryData* query) const;
  GCFSListenRequest* CreateUnwatchRequest(model::TargetId target_id) const;
  static grpc::ByteBuffer ToByteBuffer(GCFSListenRequest* request);

  /**
   * If parsing fails, will return nil and write information on the error to
   * `out_status`. Otherwise, returns the parsed proto and sets `out_status` to
   * ok.
   */
  GCFSListenResponse* ParseResponse(const grpc::ByteBuffer& message,
                                    util::Status* out_status) const;
  FSTWatchChange* ToWatchChange(GCFSListenResponse* proto) const;
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
  explicit WriteStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  void UpdateLastStreamToken(GCFSWriteResponse* proto);
  void SetLastStreamToken(NSData* token) {
    last_stream_token_ = token;
  }
  NSData* GetLastStreamToken() const {
    return last_stream_token_;
  }

  GCFSWriteRequest* CreateHandshake() const;
  GCFSWriteRequest* CreateWriteMutationsRequest(
      NSArray<FSTMutation*>* mutations) const;
  GCFSWriteRequest* CreateEmptyMutationsList() {
    return CreateWriteMutationsRequest(@[]);
  }
  static grpc::ByteBuffer ToByteBuffer(GCFSWriteRequest* request);

  /**
   * If parsing fails, will return nil and write information on the error to
   * `out_status`. Otherwise, returns the parsed proto and sets `out_status` to
   * ok.
   */
  GCFSWriteResponse* ParseResponse(const grpc::ByteBuffer& message,
                                   util::Status* out_status) const;
  model::SnapshotVersion ToCommitVersion(GCFSWriteResponse* proto) const;
  NSArray<FSTMutationResult*>* ToMutationResults(
      GCFSWriteResponse* proto) const;

  /** Creates a pretty-printed description of the proto for debugging. */
  static NSString* Describe(GCFSWriteRequest* request);
  static NSString* Describe(GCFSWriteResponse* request);

 private:
  FSTSerializerBeta* serializer_;
  NSData* last_stream_token_;
};

/**
 * A C++ bridge to `FSTSerializerBeta` that allows creating
 * `GCFSCommitRequest`s and `GCFSBatchGetDocumentsRequest`s and handling
 * `GCFSBatchGetDocumentsResponse`s.
 */
class DatastoreSerializer {
 public:
  explicit DatastoreSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  GCFSCommitRequest* CreateCommitRequest(
      NSArray<FSTMutation*>* mutations) const;
  static grpc::ByteBuffer ToByteBuffer(GCFSCommitRequest* request);

  GCFSBatchGetDocumentsRequest* CreateLookupRequest(
      const std::vector<model::DocumentKey>& keys) const;
  static grpc::ByteBuffer ToByteBuffer(GCFSBatchGetDocumentsRequest* request);

  /**
   * Merges results of the streaming read together. The array is sorted by the
   * document key.
   */
  NSArray<FSTMaybeDocument*>* MergeLookupResponses(
      const std::vector<grpc::ByteBuffer>& responses,
      util::Status* out_status) const;
  FSTMaybeDocument* ToMaybeDocument(
      GCFSBatchGetDocumentsResponse* response) const;

  FSTSerializerBeta* GetSerializer() {
    return serializer_;
  }

 private:
  FSTSerializerBeta* serializer_;
};

/** A C++ bridge that invokes methods on an `FSTWatchStreamDelegate`. */
class WatchStreamDelegate {
 public:
  explicit WatchStreamDelegate(id<FSTWatchStreamDelegate> delegate)
      : delegate_{delegate} {
  }

  void NotifyDelegateOnOpen();
  void NotifyDelegateOnChange(FSTWatchChange* change,
                              const model::SnapshotVersion& snapshot_version);
  void NotifyDelegateOnClose(const util::Status& status);

 private:
  __weak id<FSTWatchStreamDelegate> delegate_;
};

/** A C++ bridge that invokes methods on an `FSTWriteStreamDelegate`. */
class WriteStreamDelegate {
 public:
  explicit WriteStreamDelegate(id<FSTWriteStreamDelegate> delegate)
      : delegate_{delegate} {
  }

  void NotifyDelegateOnOpen();
  void NotifyDelegateOnHandshakeComplete();
  void NotifyDelegateOnCommit(const model::SnapshotVersion& commit_version,
                              NSArray<FSTMutationResult*>* results);
  void NotifyDelegateOnClose(const util::Status& status);

 private:
  __weak id<FSTWriteStreamDelegate> delegate_;
};

}  // namespace bridge
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_OBJC_BRIDGE_H_
