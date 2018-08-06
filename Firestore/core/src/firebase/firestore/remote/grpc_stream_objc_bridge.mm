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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream_objc_bridge.h"

#include <utility>

#include "Firestore/Source/Remote/FSTDatastore.h"
#include "Firestore/core/src/firebase/firestore/remote/stream_operation.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace bridge {

namespace {

NSData* ToNsData(const grpc::ByteBuffer& buffer) {
  std::vector<grpc::Slice> slices;
  const grpc::Status status = buffer.Dump(&slices);
  HARD_ASSERT(status.ok(), "Trying to convert a corrupted grpc::ByteBuffer");

  if (slices.size() == 1) {
    return [NSData dataWithBytes:slices.front().begin()
                          length:slices.front().size()];
  } else {
    NSMutableData* data = [NSMutableData dataWithCapacity:buffer.Length()];
    for (const auto& slice : slices) {
      [data appendBytes:slice.begin() length:slice.size()];
    }
    return data;
  }
}

template <typename Proto>
Proto* ParseResponse(const grpc::ByteBuffer& buffer) {
  NSError* error;
  auto* proto = [Proto parseFromData:ToNsData(buffer) error:error];
  // FIXME OBC
  if (error) {
    NSDictionary* info = @{
      NSLocalizedDescriptionKey : @"Unable to parse response from the server",
      NSUnderlyingErrorKey : error,
      @"Expected class" : [proto class],
      @"Received value" : ToNsData(message),
    };
    LOG_DEBUG("%s", [info description]);

    return nil;
  }
  return proto;
}

grpc::ByteBuffer ToByteBuffer(NSData* data) {
  const grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

}  // namespace

grpc::ByteBuffer SerializerBridge::ToByteBuffer(FSTQueryData* query) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.addTarget = [serializer_ encodedTarget:query];
  request.labels = [serializer_ encodedListenRequestLabelsForQueryData:query];

  return ToByteBuffer([request data]);
}

grpc::ByteBuffer SerializerBridge::ToByteBuffer(FSTTargetID target_id) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.removeTarget = target_id;

  return ToByteBuffer([request data]);
}

grpc::ByteBuffer SerializerBridge::CreateHandshake() const {
  // The initial request cannot contain mutations, but must contain a projectID.
  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.database = [serializer_ encodedDatabaseID];
  return ToByteBuffer([request data]);
}

grpc::ByteBuffer SerializerBridge::ToByteBuffer(
    NSArray<FSTMutation*>* mutations, const std::string& last_stream_token) {
  NSMutableArray<GCFSWrite*>* protos =
      [NSMutableArray arrayWithCapacity:mutations.count];
  for (FSTMutation* mutation in mutations) {
    [protos addObject:[_serializer encodedMutation:mutation]];
  };

  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.writesArray = protos;
  request.streamToken = util::MakeNSString(last_stream_token);
  return ToByteBuffer([request data]);
}

FSTWatchChange* SerializerBridge::ToWatchChange(
    GCFSListenResponse* proto) const {
  return [serializer_ decodedWatchChange:proto];
}

SnapshotVersion SerializerBridge::ToSnapshotVersion(
    GCFSListenResponse* proto) const {
  return [serializer_ versionFromListenResponse:proto];
}

std::string SerializerBridge::ToStreamToken(GCFSWriteResponse* proto) const {
  return util::MakeString(proto.streamToken);
}

model::SnapshotVersion SerializerBridge::ToCommitVersion(
    GCFSWriteResponse* proto) const {
  return [_serializer decodedVersion:proto.commitTime];
}

NSArray<FSTMutationResult*> SerializerBridge::ToMutationResults(
    GCFSWriteResponse* proto) const {
  NSMutableArray<GCFSWriteResult*>* protos = proto.writeResultsArray;
  NSMutableArray<FSTMutationResult*>* results =
      [NSMutableArray arrayWithCapacity:protos.count];
  for (GCFSWriteResult* proto in protos) {
    [results addObject:[_serializer decodedMutationResult:proto]];
  };
  return results;
}

void WatchStreamDelegateBridge::NotifyDelegateOnOpen() {
  id<FSTStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

NSError* WatchStreamDelegateBridge::NotifyDelegateOnChange(
    FSTWatchChange* change, const model::SnapshotVersion& snapshot_version) {
  id<FSTStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:ToWatchChange(proto)
                 snapshotVersion:ToSnapshotVersion(proto)];
}

void WatchStreamDelegateBridge::NotifyDelegateOnStreamFinished(
    const FirestoreErrorCode error_code) {
  id<FSTStreamDelegate> delegate = delegate_;
  NSError* error = util::MakeNSError(error_code, "Server error");  // TODO
  [delegate watchStreamWasInterruptedWithError:error];
}

void WriteStreamDelegateBridge::NotifyDelegateOnOpen() {
  id<FSTStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

NSError* WriteStreamDelegateBridge::NotifyDelegateOnChange(
    FSTWatchChange* change, const model::SnapshotVersion& snapshot_version) {
  id<FSTStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:ToWatchChange(proto)
                 snapshotVersion:ToSnapshotVersion(proto)];
}

void WriteStreamDelegateBridge::NotifyDelegateOnStreamFinished(
    const FirestoreErrorCode error_code) {
  id<FSTStreamDelegate> delegate = delegate_;
  NSError* error = util::MakeNSError(error_code, "Server error");  // TODO
  [delegate watchStreamWasInterruptedWithError:error];
}

}
}
}
}
