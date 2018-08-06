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

#import "Firestore/Source/Remote/FSTStream.h"

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"

#include <vector>

namespace firebase {
namespace firestore {

using model::SnapshotVersion;

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
Proto* ToProto(const grpc::ByteBuffer& message) {
  NSError* error;
  auto* proto = [Proto parseFromData:ToNsData(message) error:&error];
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

grpc::ByteBuffer ConvertToByteBuffer(NSData* data) {
  const grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

}  // namespace

grpc::ByteBuffer WatchStreamSerializer::ToByteBuffer(
    FSTQueryData* query) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.addTarget = [serializer_ encodedTarget:query];
  request.labels = [serializer_ encodedListenRequestLabelsForQueryData:query];

  return ConvertToByteBuffer([request data]);
}

grpc::ByteBuffer WatchStreamSerializer::ToByteBuffer(
    FSTTargetID target_id) const {
  GCFSListenRequest* request = [GCFSListenRequest message];
  request.database = [serializer_ encodedDatabaseID];
  request.removeTarget = target_id;

  return ConvertToByteBuffer([request data]);
}

grpc::ByteBuffer WriteStreamSerializer::CreateHandshake() const {
  // The initial request cannot contain mutations, but must contain a projectID.
  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.database = [serializer_ encodedDatabaseID];
  return ConvertToByteBuffer([request data]);
}

grpc::ByteBuffer WriteStreamSerializer::ToByteBuffer(
    NSArray<FSTMutation*>* mutations, const std::string& last_stream_token) {
  NSMutableArray<GCFSWrite*>* protos =
      [NSMutableArray arrayWithCapacity:mutations.count];
  for (FSTMutation* mutation in mutations) {
    [protos addObject:[serializer_ encodedMutation:mutation]];
  };

  GCFSWriteRequest* request = [GCFSWriteRequest message];
  request.writesArray = protos;
  request.streamToken = [util::WrapNSString(last_stream_token)
      dataUsingEncoding:NSUTF8StringEncoding];
  return ConvertToByteBuffer([request data]);
}

FSTWatchChange* WatchStreamSerializer::ToWatchChange(
    GCFSListenResponse* proto) const {
  return [serializer_ decodedWatchChange:proto];
}

SnapshotVersion WatchStreamSerializer::ToSnapshotVersion(
    GCFSListenResponse* proto) const {
  return [serializer_ versionFromListenResponse:proto];
}

GCFSListenResponse* WatchStreamSerializer::ParseResponse(
    const grpc::ByteBuffer& message) const {
  return ToProto<GCFSListenResponse>(message);
}

std::string WriteStreamSerializer::ToStreamToken(
    GCFSWriteResponse* proto) const {
  return util::MakeString([[NSString alloc] initWithData:proto.streamToken
                                                encoding:NSUTF8StringEncoding]);
}

model::SnapshotVersion WriteStreamSerializer::ToCommitVersion(
    GCFSWriteResponse* proto) const {
  return [serializer_ decodedVersion:proto.commitTime];
}

NSArray<FSTMutationResult*>* WriteStreamSerializer::ToMutationResults(
    GCFSWriteResponse* proto) const {
  NSMutableArray<GCFSWriteResult*>* protos = proto.writeResultsArray;
  NSMutableArray<FSTMutationResult*>* results =
      [NSMutableArray arrayWithCapacity:protos.count];
  for (GCFSWriteResult* proto in protos) {
    [results addObject:[serializer_ decodedMutationResult:proto]];
  };
  return results;
}

GCFSWriteResponse* WriteStreamSerializer::ParseResponse(
    const grpc::ByteBuffer& message) const {
  return ToProto<GCFSWriteResponse>(message);
}

void WatchStreamDelegate::NotifyDelegateOnOpen() {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidOpen];
}

void WatchStreamDelegate::NotifyDelegateOnChange(
    FSTWatchChange* change, const model::SnapshotVersion& snapshot_version) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  [delegate watchStreamDidChange:change snapshotVersion:snapshot_version];
}

void WatchStreamDelegate::NotifyDelegateOnStreamFinished(
    const FirestoreErrorCode error_code) {
  id<FSTWatchStreamDelegate> delegate = delegate_;
  NSError* error = util::MakeNSError(error_code, "Server error");  // TODO
  [delegate watchStreamWasInterruptedWithError:error];
}

void WriteStreamDelegate::NotifyDelegateOnOpen() {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidOpen];
}

void WriteStreamDelegate::NotifyDelegateOnHandshakeComplete() {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidCompleteHandshake];
}

void WriteStreamDelegate::NotifyDelegateOnCommit(
    const SnapshotVersion& commit_version,
    NSArray<FSTMutationResult*>* results) {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  [delegate writeStreamDidReceiveResponseWithVersion:commit_version
                                     mutationResults:results];
}

void WriteStreamDelegate::NotifyDelegateOnStreamFinished(
    const FirestoreErrorCode error_code) {
  id<FSTWriteStreamDelegate> delegate = delegate_;
  NSError* error = util::MakeNSError(error_code, "Server error");  // TODO
  [delegate writeStreamWasInterruptedWithError:error];
}
}
}
}
}
