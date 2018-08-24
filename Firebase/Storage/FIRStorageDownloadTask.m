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

#import "FIRStorageDownloadTask.h"

#import "FIRStorageConstants_Private.h"
#import "FIRStorageDownloadTask_Private.h"
#import "FIRStorageObservableTask_Private.h"
#import "FIRStorageTask_Private.h"

@implementation FIRStorageDownloadTask

@synthesize progress = _progress;
@synthesize fetcher = _fetcher;
@synthesize fetcherCompletion = _fetcherCompletion;

- (instancetype)initWithReference:(FIRStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                             file:(nullable NSURL *)fileURL {
  self = [super initWithReference:reference fetcherService:service];
  if (self) {
    _fileURL = [fileURL copy];
    _progress = [NSProgress progressWithTotalUnitCount:0];
  }
  return self;
}

- (void)dealloc {
  [_fetcher stopFetching];
}

- (void)enqueue {
  [self enqueueWithData:nil];
}

- (void)enqueueWithData:(nullable NSData *)resumeData {
  NSAssert([NSThread isMainThread],
           @"Download attempting to execute on non main queue! Please "
           @"only execute this method on the main queue.");
  self.state = FIRStorageTaskStateQueueing;
  NSMutableURLRequest *request = [self.baseRequest mutableCopy];
  request.HTTPMethod = @"GET";
  request.timeoutInterval = self.reference.storage.maxDownloadRetryTime;
  NSURLComponents *components =
      [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
  [components setQuery:@"alt=media"];
  request.URL = components.URL;

  GTMSessionFetcher *fetcher;
  if (resumeData) {
    fetcher = [GTMSessionFetcher fetcherWithDownloadResumeData:resumeData];
    fetcher.comment = @"Resuming DownloadTask";
  } else {
    fetcher = [self.fetcherService fetcherWithRequest:request];
    fetcher.comment = @"Starting DownloadTask";
  }

  __weak FIRStorageDownloadTask *weakSelf = self;

  [fetcher setResumeDataBlock:^(NSData *data) {
    if (data) {
      FIRStorageDownloadTask *strongSelf = weakSelf;
      strongSelf->_downloadData = data;
    }
  }];

  fetcher.maxRetryInterval = self.reference.storage.maxDownloadRetryTime;

  if (_fileURL) {
    // Handle file downloads
    [fetcher setDestinationFileURL:_fileURL];
    [fetcher setDownloadProgressBlock:^(int64_t bytesWritten, int64_t totalBytesWritten,
                                        int64_t totalBytesExpectedToWrite) {
      weakSelf.state = FIRStorageTaskStateProgress;
      weakSelf.progress.completedUnitCount = totalBytesWritten;
      weakSelf.progress.totalUnitCount = totalBytesExpectedToWrite;
      FIRStorageTaskSnapshot *snapshot = weakSelf.snapshot;
      [weakSelf fireHandlersForStatus:FIRStorageTaskStatusProgress snapshot:snapshot];
      weakSelf.state = FIRStorageTaskStateRunning;
    }];
  } else {
    // Handle data downloads
    [fetcher setReceivedProgressBlock:^(int64_t bytesWritten, int64_t totalBytesWritten) {
      weakSelf.state = FIRStorageTaskStateProgress;
      weakSelf.progress.completedUnitCount = totalBytesWritten;
      int64_t totalLength = [[weakSelf.fetcher response] expectedContentLength];
      weakSelf.progress.totalUnitCount = totalLength;
      FIRStorageTaskSnapshot *snapshot = weakSelf.snapshot;
      [weakSelf fireHandlersForStatus:FIRStorageTaskStatusProgress snapshot:snapshot];
      weakSelf.state = FIRStorageTaskStateRunning;
    }];
  }

  _fetcher = fetcher;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
  _fetcherCompletion = ^(NSData *data, NSError *error) {
    // Fire last progress updates
    [self fireHandlersForStatus:FIRStorageTaskStatusProgress snapshot:self.snapshot];

    // Handle potential issues with download
    if (error) {
      self.state = FIRStorageTaskStateFailed;
      self.error = [FIRStorageErrors errorWithServerError:error reference:self.reference];
      [self fireHandlersForStatus:FIRStorageTaskStatusFailure snapshot:self.snapshot];
      [self removeAllObservers];
      self->_fetcherCompletion = nil;
      return;
    }

    // Download completed successfully, fire completion callbacks
    self.state = FIRStorageTaskStateSuccess;

    if (data) {
      self->_downloadData = data;
    }

    [self fireHandlersForStatus:FIRStorageTaskStatusSuccess snapshot:self.snapshot];
    [self removeAllObservers];
    self->_fetcherCompletion = nil;
  };
#pragma clang diagnostic pop

  self.state = FIRStorageTaskStateRunning;
  [self.fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
    weakSelf.fetcherCompletion(data, error);
  }];
}

#pragma mark - Download Management

- (void)cancel {
  NSError *error = [FIRStorageErrors errorWithCode:FIRStorageErrorCodeCancelled];
  [self cancelWithError:error];
}

- (void)cancelWithError:(NSError *)error {
  NSAssert([NSThread isMainThread],
           @"Cancel attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStateCancelled;
  [self.fetcher stopFetching];
  self.error = error;
  [self fireHandlersForStatus:FIRStorageTaskStatusFailure snapshot:self.snapshot];
}

- (void)pause {
  NSAssert([NSThread isMainThread],
           @"Pause attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStatePausing;
  [self.fetcher stopFetching];
  // Give the resume callback a chance to run (if scheduled)
  [self.fetcher waitForCompletionWithTimeout:0.001];
  self.state = FIRStorageTaskStatePaused;
  FIRStorageTaskSnapshot *snapshot = self.snapshot;
  [self fireHandlersForStatus:FIRStorageTaskStatusPause snapshot:snapshot];
}

- (void)resume {
  NSAssert([NSThread isMainThread],
           @"Resume attempting to execute on non main queue! Please only "
           @"execute this method on the main queue.");
  self.state = FIRStorageTaskStateResuming;
  FIRStorageTaskSnapshot *snapshot = self.snapshot;
  [self fireHandlersForStatus:FIRStorageTaskStatusResume snapshot:snapshot];
  self.state = FIRStorageTaskStateRunning;
  [self enqueueWithData:_downloadData];
}

@end
