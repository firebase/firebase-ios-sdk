/*
 * Copyright 2017 Google
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

#import <GRPCClient/GRPCCall+OAuth2.h>
#import <GRPCClient/GRPCCall.h>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTDatastore.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Util/FSTClasses.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbrpc.h"

#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::Token;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::SnapshotVersion;

#pragma mark - FSTWatchStream

using firebase::firestore::remote::WatchStream;

@implementation FSTWatchStream {
  std::shared_ptr<WatchStream> impl_;
}

- (instancetype)initWithDatabase:(const DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(CredentialsProvider *)credentials
                      serializer:(FSTSerializerBeta *)serializer {
  impl_ = std::make_shared<WatchStream>([workerDispatchQueue implementation], credentials, serializer, nullptr, nil);
  return self;
}

- (void)watchQuery:(FSTQueryData *)query {
  impl_->WatchQuery(query);
}

- (void)unwatchTargetID:(FSTTargetID)targetID {
  impl_->UnwatchTargetId(targetID);
}

- (void)start {
  impl_->Start();
}

- (void)stop {
  impl_->Stop();
}

- (BOOL)isOpen {
  return impl_->IsOpen();
}

- (BOOL)isStarted {
  return impl_->IsStarted();
}

- (void)markIdle {
  impl_->MarkIdle();
}

@end

#pragma mark - FSTWriteStream

using firebase::firestore::remote::WriteStream;

@implementation FSTWriteStream {
  std::shared_ptr<WriteStream> impl_;
}

- (instancetype)initWithDatabase:(const DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(CredentialsProvider *)credentials
                      serializer:(FSTSerializerBeta *)serializer {
  impl_ = std::make_shared<WriteStream>([workerDispatchQueue implementation], credentials, serializer, nullptr, nil);
  return self;
}

- (void)start {
  impl_->Start();
}

- (void)stop {
  impl_->Stop();
}

- (BOOL)isOpen {
  return impl_->IsOpen();
}

- (BOOL)isStarted {
  return impl_->IsStarted();
}

- (void)markIdle {
  impl_->MarkIdle();
}

- (void)writeHandshake {
  impl_->WriteHandshake();
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations {
  impl_->WriteMutations(mutations);
}

- (void) setHandshakeComplete {
  impl_->SetHandshakeComplete();
}

- (BOOL) isHandshakeComplete {
  return impl_->IsHandshakeComplete();
}

- (NSData *) lastStreamToken {
  return impl_->GetLastStreamToken();
}

@end
