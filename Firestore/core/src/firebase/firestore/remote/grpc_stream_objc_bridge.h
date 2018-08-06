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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_OBJC_BRIDGE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_OBJC_BRIDGE_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#include <grpcpp/support/byte_buffer.h>

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"
#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace bridge {

// Contains operations that are still delegated to Objective-C: proto parsing
// and delegates.

class WatchStreamSerializer {
 public:
  explicit WatchStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  grpc::ByteBuffer ToByteBuffer(FSTQueryData* query) const;
  grpc::ByteBuffer ToByteBuffer(FSTTargetID target_id) const;

  FSTWatchChange* ToWatchChange(GCFSListenResponse* proto) const;
  model::SnapshotVersion ToSnapshotVersion(GCFSListenResponse* proto) const;

  GCFSListenResponse* ParseListenResponse(GCFSListenResponse* proto) const;

 private:
  FSTSerializerBeta* serializer_;
};

class WriteStreamSerializer {
 public:
  explicit WriteStreamSerializer(FSTSerializerBeta* serializer)
      : serializer_{serializer} {
  }

  grpc::ByteBuffer ToByteBuffer(NSArray<FSTMutation*>* mutations,
                                const std::string& last_stream_token);


  std::string ToStreamToken(GCFSWriteResponse* proto) const;
  model::SnapshotVersion ToCommitVersion(GCFSWriteResponse* proto) const;
  NSArray<FSTMutationResult*> ToMutationResults(GCFSWriteResponse* proto) const;

  GCFSListenResponse* ParseWriteResponse(GCFSWriteResponse* proto) const;

  grpc::ByteBuffer CreateHandshake() const;

 private:
  FSTSerializerBeta* serializer_;
};

class WatchStreamDelegate {
 public:
  explicit WatchStreamDelegate(id delegate) : delegate_{delegate} {
  }

  void NotifyDelegateOnOpen();
  void NotifyDelegateOnChange(FSTWatchChange* change,
                              const model::SnapshotVersion& snapshot_version);
  void NotifyDelegateOnStreamFinished(FirestoreErrorCode error_code);

 private:
  id delegate_;
};

class WriteStreamDelegate {
 public:
  explicit WriteStreamDelegate(id delegate) : delegate_{delegate} {
  }

  void NotifyDelegateOnOpen();
  void NotifyDelegateOnHandshakeComplete();
  void NotifyDelegateOnCommit(NSArray<FSTMutationResult*>* results,
                              const model::SnapshotVersion& commit_version);
  void NotifyDelegateOnStreamFinished(FirestoreErrorCode error_code);

 private:
  id delegate_;
};

}  // namespace bridge
}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_OBJC_BRIDGE_H_
