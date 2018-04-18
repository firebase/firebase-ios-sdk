// Copyright 2017 Google
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

#import "FIRStorageUploadTask.h"

#import "FIRStorageConstants_Private.h"
#import "FIRStorageMetadata_Private.h"
#import "FIRStorageObservableTask_Private.h"
#import "FIRStorageTask_Private.h"
#import "FIRStorageUploadTask_Private.h"

#import "GTMSessionUploadFetcher.h"

@implementation FIRStorageUploadTask

@synthesize progress = _progress;
@synthesize fetcherCompletion = _fetcherCompletion;

- (instancetype)initWithReference:(FIRStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                             data:(NSData *)uploadData
                         metadata:(FIRStorageMetadata *)metadata {
  self = [super initWithReference:reference fetcherService:service];
  if (self) {
    _uploadMetadata = [metadata copy];
    _uploadData = [uploadData copy];
    _progress = [NSProgress progressWithTotalUnitCount:[_uploadData length]];

    if (!_uploadMetadata.contentType) {
      _uploadMetadata.contentType = @"application/octet-stream";
    }
  }
  return self;
}

- (instancetype)initWithReference:(FIRStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                             file:(NSURL *)fileURL
                         metadata:(FIRStorageMetadata *)metadata {
  self = [super initWithReference:reference fetcherService:service];
  if (self) {
    _uploadMetadata = [metadata copy];
    _fileURL = [fileURL copy];
    _progress = [NSProgress progressWithTotalUnitCount:0];

    NSString *mimeType = [FIRStorageUtils MIMETypeForExtension:[_fileURL pathExtension]];

    if (!_uploadMetadata.contentType) {
      _uploadMetadata.contentType = mimeType ?: @"application/octet-stream";
    }
  }
  return self;
}

- (void)dealloc {
  [_uploadFetcher stopFetching];
}

- (void)enqueue {
  NSAssert([NSThread isMainThread],
           @"Upload attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStateQueueing;

  NSMutableURLRequest *request = [self.baseRequest mutableCopy];
  request.HTTPMethod = @"POST";
  request.timeoutInterval = self.reference.storage.maxUploadRetryTime;
  NSData *bodyData = [NSData frs_dataFromJSONDictionary:[_uploadMetadata dictionaryRepresentation]];
  request.HTTPBody = bodyData;
  [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
  NSString *contentLengthString =
      [NSString stringWithFormat:@"%zu", (unsigned long)[bodyData length]];
  [request setValue:contentLengthString forHTTPHeaderField:@"Content-Length"];

  NSURLComponents *components =
      [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];

  if ([components.host isEqual:kGCSHost]) {
    [components setPercentEncodedPath:[@"/upload" stringByAppendingString:components.path]];
  }

  NSDictionary *queryParams = @{@"uploadType" : @"resumable", @"name" : self.uploadMetadata.path};
  [components setPercentEncodedQuery:[FIRStorageUtils queryStringForDictionary:queryParams]];
  request.URL = components.URL;

  GTMSessionUploadFetcher *uploadFetcher =
      [GTMSessionUploadFetcher uploadFetcherWithRequest:request
                                         uploadMIMEType:_uploadMetadata.contentType
                                              chunkSize:kGTMSessionUploadFetcherStandardChunkSize
                                         fetcherService:self.fetcherService];

  if (_uploadData) {
    [uploadFetcher setUploadData:_uploadData];
    uploadFetcher.comment = @"Data UploadTask";
  } else if (_fileURL) {
    [uploadFetcher setUploadFileURL:_fileURL];
    uploadFetcher.comment = @"File UploadTask";
  }

  uploadFetcher.maxRetryInterval = self.reference.storage.maxUploadRetryTime;

  __weak FIRStorageUploadTask *weakSelf = self;

  [uploadFetcher setSendProgressBlock:^(int64_t bytesSent, int64_t totalBytesSent,
                                        int64_t totalBytesExpectedToSend) {
    weakSelf.state = FIRStorageTaskStateProgress;
    weakSelf.progress.completedUnitCount = totalBytesSent;
    weakSelf.progress.totalUnitCount = totalBytesExpectedToSend;
    weakSelf.metadata = self->_uploadMetadata;
    [weakSelf fireHandlersForStatus:FIRStorageTaskStatusProgress snapshot:weakSelf.snapshot];
    weakSelf.state = FIRStorageTaskStateRunning;
  }];

  _uploadFetcher = uploadFetcher;

  // Process fetches
  self.state = FIRStorageTaskStateRunning;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
  _fetcherCompletion = ^(NSData *_Nullable data, NSError *_Nullable error) {
    // Fire last progress updates
    [self fireHandlersForStatus:FIRStorageTaskStatusProgress snapshot:self.snapshot];

    // Handle potential issues with upload
    if (error) {
      self.state = FIRStorageTaskStateFailed;
      self.error = [FIRStorageErrors errorWithServerError:error reference:self.reference];
      self.metadata = self->_uploadMetadata;
      [self fireHandlersForStatus:FIRStorageTaskStatusFailure snapshot:self.snapshot];
      [self removeAllObservers];
      self->_fetcherCompletion = nil;
      return;
    }

    // Upload completed successfully, fire completion callbacks
    self.state = FIRStorageTaskStateSuccess;

    NSDictionary *responseDictionary = [NSDictionary frs_dictionaryFromJSONData:data];
    if (responseDictionary) {
      FIRStorageMetadata *metadata =
          [[FIRStorageMetadata alloc] initWithDictionary:responseDictionary];
      [metadata setType:FIRStorageMetadataTypeFile];
      self.metadata = metadata;
    } else {
      self.error = [FIRStorageErrors errorWithInvalidRequest:data];
    }

    [self fireHandlersForStatus:FIRStorageTaskStatusSuccess snapshot:self.snapshot];
    [self removeAllObservers];
    self->_fetcherCompletion = nil;
  };
#pragma clang diagnostic pop

  [_uploadFetcher
      beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
        weakSelf.fetcherCompletion(data, error);
      }];
}

#pragma mark - Upload Management

- (void)cancel {
  NSAssert([NSThread isMainThread],
           @"Cancel attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStateCancelled;
  [_uploadFetcher stopFetching];
  if (self.state != FIRStorageTaskStateSuccess) {
    self.metadata = _uploadMetadata;
  }
  self.error = [FIRStorageErrors errorWithCode:FIRStorageErrorCodeCancelled];
  [self fireHandlersForStatus:FIRStorageTaskStatusFailure snapshot:self.snapshot];
}

- (void)pause {
  NSAssert([NSThread isMainThread],
           @"Pause attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStatePaused;
  [_uploadFetcher pauseFetching];
  if (self.state != FIRStorageTaskStateSuccess) {
    self.metadata = _uploadMetadata;
  }
  [self fireHandlersForStatus:FIRStorageTaskStatusPause snapshot:self.snapshot];
}

- (void)resume {
  NSAssert([NSThread isMainThread],
           @"Resume attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStateResuming;
  [_uploadFetcher resumeFetching];
  if (self.state != FIRStorageTaskStateSuccess) {
    self.metadata = _uploadMetadata;
  }
  [self fireHandlersForStatus:FIRStorageTaskStatusResume snapshot:self.snapshot];
  self.state = FIRStorageTaskStateRunning;
}

@end
