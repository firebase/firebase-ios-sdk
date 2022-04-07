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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageUploadTask.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageMetadata_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageObservableTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUploadTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorage_Private.h"

#if SWIFT_PACKAGE
@import GTMSessionFetcherCore;
#else
#import <GTMSessionFetcher/GTMSessionUploadFetcher.h>
#endif

@implementation FIRIMPLStorageUploadTask

@synthesize progress = _progress;
@synthesize fetcherCompletion = _fetcherCompletion;

- (instancetype)initWithReference:(FIRIMPLStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                    dispatchQueue:(dispatch_queue_t)queue
                             data:(NSData *)uploadData
                         metadata:(FIRIMPLStorageMetadata *)metadata {
  self = [super initWithReference:reference fetcherService:service dispatchQueue:queue];
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

- (instancetype)initWithReference:(FIRIMPLStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                    dispatchQueue:(dispatch_queue_t)queue
                             file:(NSURL *)fileURL
                         metadata:(FIRIMPLStorageMetadata *)metadata {
  self = [super initWithReference:reference fetcherService:service dispatchQueue:queue];
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
  __weak FIRIMPLStorageUploadTask *weakSelf = self;

  [self dispatchAsync:^() {
    FIRIMPLStorageUploadTask *strongSelf = weakSelf;

    if (!strongSelf) {
      return;
    }

    NSError *contentValidationError;
    if (![strongSelf isContentToUploadValid:&contentValidationError]) {
      strongSelf.error = contentValidationError;
      [strongSelf finishTaskWithStatus:FIRIMPLStorageTaskStatusFailure
                              snapshot:strongSelf.snapshot];
      return;
    }

    strongSelf.state = FIRIMPLStorageTaskStateQueueing;

    NSMutableURLRequest *request = [strongSelf.baseRequest mutableCopy];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = strongSelf.reference.storage.maxUploadRetryTime;
    NSData *bodyData =
        [NSData frs_dataFromJSONDictionary:[strongSelf->_uploadMetadata dictionaryRepresentation]];
    request.HTTPBody = bodyData;
    [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    NSString *contentLengthString =
        [NSString stringWithFormat:@"%zu", (unsigned long)[bodyData length]];
    [request setValue:contentLengthString forHTTPHeaderField:@"Content-Length"];

    NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL
                                             resolvingAgainstBaseURL:NO];

    if ([components.host isEqual:kGCSHost]) {
      [components setPercentEncodedPath:[@"/upload" stringByAppendingString:components.path]];
    }

    NSDictionary *queryParams = @{@"uploadType" : @"resumable", @"name" : self.uploadMetadata.path};
    [components setPercentEncodedQuery:[FIRStorageUtils queryStringForDictionary:queryParams]];
    request.URL = components.URL;

    GTMSessionUploadFetcher *uploadFetcher =
        [GTMSessionUploadFetcher uploadFetcherWithRequest:request
                                           uploadMIMEType:strongSelf->_uploadMetadata.contentType
                                                chunkSize:kGTMSessionUploadFetcherStandardChunkSize
                                           fetcherService:self.fetcherService];

    if (strongSelf->_uploadData) {
      [uploadFetcher setUploadData:strongSelf->_uploadData];
      uploadFetcher.comment = @"Data UploadTask";
    } else if (strongSelf->_fileURL) {
      [uploadFetcher setUploadFileURL:strongSelf->_fileURL];
      uploadFetcher.comment = @"File UploadTask";
    }

    uploadFetcher.maxRetryInterval = self.reference.storage.maxUploadRetryInterval;

    [uploadFetcher setSendProgressBlock:^(int64_t bytesSent, int64_t totalBytesSent,
                                          int64_t totalBytesExpectedToSend) {
      weakSelf.state = FIRIMPLStorageTaskStateProgress;
      weakSelf.progress.completedUnitCount = totalBytesSent;
      weakSelf.progress.totalUnitCount = totalBytesExpectedToSend;
      weakSelf.metadata = self->_uploadMetadata;
      [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusProgress snapshot:weakSelf.snapshot];
      weakSelf.state = FIRIMPLStorageTaskStateRunning;
    }];

    strongSelf->_uploadFetcher = uploadFetcher;

    // Process fetches
    strongSelf.state = FIRIMPLStorageTaskStateRunning;

    strongSelf->_fetcherCompletion = ^(NSData *_Nullable data, NSError *_Nullable error) {
      // Fire last progress updates
      [self fireHandlersForStatus:FIRIMPLStorageTaskStatusProgress snapshot:self.snapshot];

      // Handle potential issues with upload
      if (error) {
        self.state = FIRIMPLStorageTaskStateFailed;
        self.error = [FIRStorageErrors errorWithServerError:error reference:self.reference];
        self.metadata = self->_uploadMetadata;

        [self finishTaskWithStatus:FIRIMPLStorageTaskStatusFailure snapshot:self.snapshot];
        return;
      }

      // Upload completed successfully, fire completion callbacks
      self.state = FIRIMPLStorageTaskStateSuccess;

      NSDictionary *responseDictionary = [NSDictionary frs_dictionaryFromJSONData:data];
      if (responseDictionary) {
        FIRIMPLStorageMetadata *metadata =
            [[FIRIMPLStorageMetadata alloc] initWithDictionary:responseDictionary];
        [metadata setType:FIRStorageMetadataTypeFile];
        self.metadata = metadata;
      } else {
        self.error = [FIRStorageErrors errorWithInvalidRequest:data];
      }

      [self finishTaskWithStatus:FIRIMPLStorageTaskStatusSuccess snapshot:self.snapshot];
    };

    [strongSelf->_uploadFetcher
        beginFetchWithCompletionHandler:^(NSData *_Nullable data, NSError *_Nullable error) {
          FIRIMPLStorageUploadTask *strongSelf = weakSelf;
          if (strongSelf.fetcherCompletion) {
            strongSelf.fetcherCompletion(data, error);
          }
        }];
  }];
}

- (void)finishTaskWithStatus:(FIRIMPLStorageTaskStatus)status
                    snapshot:(FIRIMPLStorageTaskSnapshot *)snapshot {
  [self fireHandlersForStatus:status snapshot:self.snapshot];
  [self removeAllObservers];
  self->_fetcherCompletion = nil;
}

- (BOOL)isContentToUploadValid:(NSError **)outError {
  if (_uploadData != nil) {
    return YES;
  }

  NSError *fileReachabilityError;
  if (![_fileURL checkResourceIsReachableAndReturnError:&fileReachabilityError] ||
      ![self fileURLisFile:_fileURL]) {
    if (outError != NULL) {
      NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
      userInfo[NSLocalizedDescriptionKey] = [NSString
          stringWithFormat:@"File at URL: %@ is not reachable. "
                           @"Ensure file URL is not a directory, symbolic link, or invalid url.",
                           _fileURL.absoluteString];

      if (fileReachabilityError) {
        userInfo[NSUnderlyingErrorKey] = fileReachabilityError;
      }

      *outError = [NSError errorWithDomain:FIRStorageErrorDomainInternal
                                      code:FIRIMPLStorageErrorCodeUnknown
                                  userInfo:userInfo];
    }

    return NO;
  }

  return YES;
}

#pragma mark - Upload Management

- (void)cancel {
  __weak FIRIMPLStorageUploadTask *weakSelf = self;

  [self dispatchAsync:^() {
    weakSelf.state = FIRIMPLStorageTaskStateCancelled;
    [weakSelf.uploadFetcher stopFetching];
    if (weakSelf.state != FIRIMPLStorageTaskStateSuccess) {
      weakSelf.metadata = weakSelf.uploadMetadata;
    }
    weakSelf.error = [FIRStorageErrors errorWithCode:FIRIMPLStorageErrorCodeCancelled];
    [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusFailure snapshot:weakSelf.snapshot];
  }];
}

- (void)pause {
  __weak FIRIMPLStorageUploadTask *weakSelf = self;

  [self dispatchAsync:^() {
    weakSelf.state = FIRIMPLStorageTaskStatePaused;
    [weakSelf.uploadFetcher pauseFetching];
    if (weakSelf.state != FIRIMPLStorageTaskStateSuccess) {
      weakSelf.metadata = weakSelf.uploadMetadata;
    }
    [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusPause snapshot:weakSelf.snapshot];
  }];
}

- (void)resume {
  __weak FIRIMPLStorageUploadTask *weakSelf = self;

  [self dispatchAsync:^() {
    weakSelf.state = FIRIMPLStorageTaskStateResuming;
    [weakSelf.uploadFetcher resumeFetching];
    if (weakSelf.state != FIRIMPLStorageTaskStateSuccess) {
      weakSelf.metadata = weakSelf.uploadMetadata;
    }
    [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusResume snapshot:weakSelf.snapshot];
    weakSelf.state = FIRIMPLStorageTaskStateRunning;
  }];
}

#pragma mark - Private Helpers

- (BOOL)fileURLisFile:(NSURL *)fileURL {
  NSNumber *isFile = [NSNumber numberWithBool:NO];
  [fileURL getResourceValue:&isFile forKey:NSURLIsRegularFileKey error:nil];
  return [isFile boolValue];
}

@end
