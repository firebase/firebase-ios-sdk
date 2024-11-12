// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <XCTest/XCTest.h>

@import FirebaseCore;
@import FirebaseStorage;

@interface ObjCAPICoverage : XCTestCase
@end

@implementation ObjCAPICoverage

- (void)FIRStorageApis {
  FIRApp *app = [FIRApp defaultApp];
  FIRStorage *storage = [FIRStorage storage];
  storage = [FIRStorage storageForApp:app];
  storage = [FIRStorage storageWithURL:@"my-url"];
  storage = [FIRStorage storageForApp:app URL:@"my-url"];
  app = [storage app];
  app = storage.app;
  [storage setMaxUploadRetryTime:[storage maxUploadRetryTime]];
  storage.maxUploadRetryTime = storage.maxUploadRetryTime + 1;
  [storage setMaxDownloadRetryTime:[storage maxDownloadRetryTime]];
  storage.maxDownloadRetryTime = storage.maxDownloadRetryTime + 1;
  [storage setMaxOperationRetryTime:[storage maxOperationRetryTime]];
  [storage setCallbackQueue:[storage callbackQueue]];
  FIRStorageReference *ref = [storage reference];
  ref = [storage referenceForURL:@"my-url"];
  ref = [storage referenceWithPath:@"my-path"];
  [storage useEmulatorWithHost:@"my-host" port:123];
}

- (void)FIRStorageReferenceApis {
  FIRStorageReference *ref = [[FIRStorage storage] reference];
  [ref storage];
  [ref bucket];
  [ref fullPath];
  [ref name];

  ref = [ref root];
  ref = [ref parent];
  ref = [ref child:@"path"];

  NSData *data = [NSData data];
  FIRStorageUploadTask *task = [ref putData:data];
  task = [ref putData:data metadata:nil];
  task = [ref putData:data
             metadata:nil
           completion:^(FIRStorageMetadata *_Nullable metadata, NSError *_Nullable error){
           }];

  NSURL *file = [NSURL URLWithString:@"my-url"];
  task = [ref putFile:file];
  task = [ref putFile:file metadata:nil];
  task = [ref putFile:file
             metadata:nil
           completion:^(FIRStorageMetadata *_Nullable metadata, NSError *_Nullable error){
           }];

  FIRStorageDownloadTask *task2 =
      [ref dataWithMaxSize:123
                completion:^(NSData *_Nullable data, NSError *_Nullable error){
                }];

  [ref downloadURLWithCompletion:^(NSURL *_Nullable URL, NSError *_Nullable error){
  }];

  task2 = [ref writeToFile:file];
  task2 = [ref writeToFile:file
                completion:^(NSURL *_Nullable URL, NSError *_Nullable error){
                }];

  [ref listAllWithCompletion:^(FIRStorageListResult *_Nonnull result, NSError *_Nullable error){
  }];

  [ref listWithMaxResults:123
               completion:^(FIRStorageListResult *_Nonnull result, NSError *_Nullable error){
               }];
  [ref listWithMaxResults:123
                pageToken:@"my token"
               completion:^(FIRStorageListResult *_Nonnull result, NSError *_Nullable error){
               }];

  [ref metadataWithCompletion:^(FIRStorageMetadata *_Nullable metadata, NSError *_Nullable error) {
    [ref updateMetadata:metadata
             completion:^(FIRStorageMetadata *_Nullable metadata, NSError *_Nullable error){
             }];
  }];

  [ref deleteWithCompletion:^(NSError *_Nullable error){
  }];
}

#ifdef COCOAPODS
- (void)FIRStorageConstantsTypedefs {
  FIRStorageHandle __unused handle;
  FIRStorageVoidDataError __unused funcPtr1;
  FIRStorageVoidError __unused funcPtr2;
  FIRStorageVoidMetadata __unused funcPtr3;
  FIRStorageVoidMetadataError __unused funcPtr4;
  FIRStorageVoidSnapshot __unused funcPtr5;
  FIRStorageVoidURLError __unused funcPtr6;
}
#endif

- (void)FIRStorageListResultApis:(FIRStorageListResult *)result {
  NSArray<FIRStorageReference *> __unused *prefixes = [result prefixes];
  NSArray<FIRStorageReference *> __unused *items = [result items];
  NSString __unused *token = [result pageToken];
}

- (FIRStorageTaskStatus)taskStatuses:(FIRStorageTaskStatus)status {
  switch (status) {
    case FIRStorageTaskStatusUnknown:
    case FIRStorageTaskStatusResume:
    case FIRStorageTaskStatusProgress:
    case FIRStorageTaskStatusPause:
    case FIRStorageTaskStatusSuccess:
    case FIRStorageTaskStatusFailure:
      return status;
  }
}

- (FIRStorageErrorCode)errorCodes:(NSError *)error {
  switch (error.code) {
    case FIRStorageErrorCodeUnknown:
    case FIRStorageErrorCodeObjectNotFound:
    case FIRStorageErrorCodeBucketNotFound:
    case FIRStorageErrorCodeProjectNotFound:
    case FIRStorageErrorCodeQuotaExceeded:
    case FIRStorageErrorCodeUnauthenticated:
    case FIRStorageErrorCodeUnauthorized:
    case FIRStorageErrorCodeRetryLimitExceeded:
    case FIRStorageErrorCodeNonMatchingChecksum:
    case FIRStorageErrorCodeDownloadSizeExceeded:
    case FIRStorageErrorCodeCancelled:
    case FIRStorageErrorCodeInvalidArgument:
      return error.code;
  }
  return error.code;
}

- (void)FIRStorageMetadataApis {
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:@{}];
  [metadata bucket];
  [metadata setCacheControl:[metadata cacheControl]];
  [metadata setContentDisposition:[metadata contentDisposition]];
  [metadata setContentEncoding:[metadata contentEncoding]];
  [metadata setContentLanguage:[metadata contentLanguage]];
  [metadata setContentType:[metadata contentType]];
  [metadata md5Hash];
  [metadata generation];
  [metadata setCustomMetadata:[metadata customMetadata]];
  [metadata metageneration];
  [metadata name];
  [metadata path];
  [metadata size];
  [metadata timeCreated];
  [metadata updated];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [metadata storageReference];
#pragma clang diagnostic pop
  FIRStorageMetadata __unused *ref2 = [metadata initWithDictionary:@{}];
  NSDictionary<NSString *, id> __unused *dict = [metadata dictionaryRepresentation];
  [metadata isFile];
  [metadata isFolder];
}

- (void)FIRStorageObservableTaskApis {
  FIRStorageReference *ref = [[FIRStorage storage] reference];
  FIRStorageObservableTask *task = [ref writeToFile:[NSURL URLWithString:@"my-url"]];

  NSString __unused *handle = [task observeStatus:FIRStorageTaskStatusPause
                                          handler:^(FIRStorageTaskSnapshot *_Nonnull snapshot){
                                          }];

  [task removeObserverWithHandle:@"handle"];

  [task removeAllObserversForStatus:FIRStorageTaskStatusUnknown];

  [task removeAllObservers];
}

- (void)FIRStorageTaskApis {
  FIRStorageReference *ref = [[FIRStorage storage] reference];
  FIRStorageTask *task = [ref writeToFile:[NSURL URLWithString:@"my-url"]];
  [task snapshot];
}

- (void)FIRStorageTaskManagementApis:(id<FIRStorageTaskManagement>)task {
  [task enqueue];
  [task pause];
  [task cancel];
  [task resume];
}

- (void)FIRStorageTaskSnapshotApis:(FIRStorageTaskSnapshot *)snapshot {
  [snapshot task];
  [snapshot metadata];
  [snapshot reference];
  [snapshot progress];
  [snapshot error];
  [snapshot status];
}

@end
