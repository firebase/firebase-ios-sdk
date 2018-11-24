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

#import "Firestore/Source/Remote/FSTDatastore.h"

#include <map>
#include <memory>
#include <vector>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRFirestoreVersion.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/error_apple.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"
#include "grpcpp/support/status_code_enum.h"

namespace util = firebase::firestore::util;
using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::Token;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::Datastore;
using firebase::firestore::remote::GrpcConnection;
using firebase::firestore::remote::WatchStream;
using firebase::firestore::remote::WriteStream;
using util::AsyncQueue;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTDatastore

@interface FSTDatastore ()

/**
 * An object for getting an auth token before each request. Does not own the CredentialsProvider
 * instance.
 */
@property(nonatomic, assign, readonly) CredentialsProvider *credentials;

@property(nonatomic, strong, readonly) FSTSerializerBeta *serializer;

@end

@implementation FSTDatastore {
  AsyncQueue *_workerQueue;
  std::shared_ptr<Datastore> _datastore;
}

+ (instancetype)datastoreWithDatabase:(const DatabaseInfo *)databaseInfo
                          workerQueue:(AsyncQueue *)workerQueue
                          credentials:(CredentialsProvider *)credentials {
  return [[FSTDatastore alloc] initWithDatabaseInfo:databaseInfo
                                        workerQueue:workerQueue
                                        credentials:credentials];
}

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo *)databaseInfo
                         workerQueue:(AsyncQueue *)workerQueue
                         credentials:(CredentialsProvider *)credentials {
  if (self = [super init]) {
    _databaseInfo = databaseInfo;
    _workerQueue = workerQueue;
    _credentials = credentials;
    _serializer = [[FSTSerializerBeta alloc] initWithDatabaseID:&databaseInfo->database_id()];

    _datastore =
        std::make_shared<Datastore>(*_databaseInfo, _workerQueue, _credentials, _serializer);
    _datastore->Start();
    if (!databaseInfo->ssl_enabled()) {
      GrpcConnection::UseInsecureChannel(databaseInfo->host());
    }
  }
  return self;
}

- (void)shutdown {
  _datastore->Shutdown();
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<FSTDatastore: <DatabaseInfo: database_id:%s host:%s>>",
                                    self.databaseInfo->database_id().database_id().c_str(),
                                    self.databaseInfo->host().c_str()];
}

- (void)commitMutations:(NSArray<FSTMutation *> *)mutations
             completion:(FSTVoidErrorBlock)completion {
  _datastore->CommitMutations(mutations, completion);
}

- (void)lookupDocuments:(const std::vector<DocumentKey> &)keys
             completion:(FSTVoidMaybeDocumentArrayErrorBlock)completion {
  _datastore->LookupDocuments(keys, completion);
}

- (std::shared_ptr<WatchStream>)createWatchStreamWithDelegate:(id)delegate {
  return _datastore->CreateWatchStream(delegate);
}

- (std::shared_ptr<WriteStream>)createWriteStreamWithDelegate:(id)delegate {
  return _datastore->CreateWriteStream(delegate);
}

@end

NS_ASSUME_NONNULL_END
