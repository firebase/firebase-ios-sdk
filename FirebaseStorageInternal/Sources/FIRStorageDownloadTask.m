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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageDownloadTask.h"

#import "FirebaseStorageInternal/Sources/FIRStorageConstants_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageDownloadTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageObservableTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorage_Private.h"

@implementation FIRIMPLStorageDownloadTask

@synthesize progress = _progress;
@synthesize fetcher = _fetcher;
@synthesize fetcherCompletion = _fetcherCompletion;

- (instancetype)initWithReference:(FIRIMPLStorageReference *)reference
                   fetcherService:(GTMSessionFetcherService *)service
                    dispatchQueue:(dispatch_queue_t)queue
                             file:(nullable NSURL *)fileURL {
  self = [super initWithReference:reference fetcherService:service dispatchQueue:queue];
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
  __weak FIRIMPLStorageDownloadTask *weakSelf = self;

  [self dispatchAsync:^() {
    FIRIMPLStorageDownloadTask *strongSelf = weakSelf;

    if (!strongSelf) {
      return;
    }

    strongSelf.state = FIRIMPLStorageTaskStateQueueing;
    NSMutableURLRequest *request = [strongSelf.baseRequest mutableCopy];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = strongSelf.reference.storage.maxDownloadRetryTime;
    NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL
                                             resolvingAgainstBaseURL:NO];
    [components setQuery:@"alt=media"];
    request.URL = components.URL;

    GTMSessionFetcher *fetcher;
    if (resumeData) {
      fetcher = [GTMSessionFetcher fetcherWithDownloadResumeData:resumeData];
      fetcher.comment = @"Resuming DownloadTask";
    } else {
      fetcher = [strongSelf.fetcherService fetcherWithRequest:request];
      fetcher.comment = @"Starting DownloadTask";
    }

    [fetcher setResumeDataBlock:^(NSData *data) {
      FIRIMPLStorageDownloadTask *strong = weakSelf;
      if (strong && data) {
        strong->_downloadData = data;
      }
    }];

    fetcher.maxRetryInterval = strongSelf.reference.storage.maxDownloadRetryInterval;

    if (strongSelf->_fileURL) {
      // Handle file downloads
      [fetcher setDestinationFileURL:strongSelf->_fileURL];
      [fetcher setDownloadProgressBlock:^(int64_t bytesWritten, int64_t totalBytesWritten,
                                          int64_t totalBytesExpectedToWrite) {
        weakSelf.state = FIRIMPLStorageTaskStateProgress;
        weakSelf.progress.completedUnitCount = totalBytesWritten;
        weakSelf.progress.totalUnitCount = totalBytesExpectedToWrite;
        FIRIMPLStorageTaskSnapshot *snapshot = weakSelf.snapshot;
        [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusProgress snapshot:snapshot];
        weakSelf.state = FIRIMPLStorageTaskStateRunning;
      }];
    } else {
      // Handle data downloads
      [fetcher setReceivedProgressBlock:^(int64_t bytesWritten, int64_t totalBytesWritten) {
        weakSelf.state = FIRIMPLStorageTaskStateProgress;
        weakSelf.progress.completedUnitCount = totalBytesWritten;
        int64_t totalLength = [[weakSelf.fetcher response] expectedContentLength];
        weakSelf.progress.totalUnitCount = totalLength;
        FIRIMPLStorageTaskSnapshot *snapshot = weakSelf.snapshot;
        [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusProgress snapshot:snapshot];
        weakSelf.state = FIRIMPLStorageTaskStateRunning;
      }];
    }

    strongSelf->_fetcher = fetcher;
    strongSelf->_fetcherCompletion = ^(NSData *data, NSError *error) {
      // Fire last progress updates
      [self fireHandlersForStatus:FIRIMPLStorageTaskStatusProgress snapshot:self.snapshot];

      // Handle potential issues with download
      if (error) {
        self.state = FIRIMPLStorageTaskStateFailed;
        self.error = [FIRStorageErrors errorWithServerError:error reference:self.reference];
        [self fireHandlersForStatus:FIRIMPLStorageTaskStatusFailure snapshot:self.snapshot];
        [self removeAllObservers];
        self->_fetcherCompletion = nil;
        return;
      }

      // Download completed successfully, fire completion callbacks
      self.state = FIRIMPLStorageTaskStateSuccess;

      if (data) {
        self->_downloadData = data;
      }

      [self fireHandlersForStatus:FIRIMPLStorageTaskStatusSuccess snapshot:self.snapshot];
      [self removeAllObservers];
      self->_fetcherCompletion = nil;
    };

    strongSelf.state = FIRIMPLStorageTaskStateRunning;
    [strongSelf.fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
      FIRIMPLStorageDownloadTask *strongSelf = weakSelf;
      if (strongSelf.fetcherCompletion) {
        strongSelf.fetcherCompletion(data, error);
      }
    }];
  }];
}

#pragma mark - Download Management

- (void)cancel {
  NSError *error = [FIRStorageErrors errorWithCode:FIRIMPLStorageErrorCodeCancelled];
  [self cancelWithError:error];
}

- (void)cancelWithError:(NSError *)error {
  __weak FIRIMPLStorageDownloadTask *weakSelf = self;
  [self dispatchAsync:^() {
    weakSelf.state = FIRIMPLStorageTaskStateCancelled;
    [weakSelf.fetcher stopFetching];
    weakSelf.error = error;
    [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusFailure snapshot:weakSelf.snapshot];
  }];
}

- (void)pause {
  __weak FIRIMPLStorageDownloadTask *weakSelf = self;
  [self dispatchAsync:^() {
    __strong FIRIMPLStorageDownloadTask *strongSelf = weakSelf;
    if (!strongSelf || strongSelf.state == FIRIMPLStorageTaskStatePaused ||
        strongSelf.state == FIRIMPLStorageTaskStatePausing) {
      return;
    }
    strongSelf.state = FIRIMPLStorageTaskStatePausing;
    // Use the resume callback to confirm pause status since it always runs after the last
    // NSURLSession update.
    [strongSelf.fetcher setResumeDataBlock:^(NSData *data) {
      // Silence compiler warning about retain cycles
      __strong __typeof(self) strong = weakSelf;
      strong->_downloadData = data;
      strong.state = FIRIMPLStorageTaskStatePaused;
      FIRIMPLStorageTaskSnapshot *snapshot = strong.snapshot;
      [strong fireHandlersForStatus:FIRIMPLStorageTaskStatusPause snapshot:snapshot];
    }];
    [strongSelf.fetcher stopFetching];
  }];
}

- (void)resume {
  __weak FIRIMPLStorageDownloadTask *weakSelf = self;
  [self dispatchAsync:^() {
    weakSelf.state = FIRIMPLStorageTaskStateResuming;
    FIRIMPLStorageTaskSnapshot *snapshot = weakSelf.snapshot;
    [weakSelf fireHandlersForStatus:FIRIMPLStorageTaskStatusResume snapshot:snapshot];
    weakSelf.state = FIRIMPLStorageTaskStateRunning;
    [weakSelf enqueueWithData:weakSelf.downloadData];
  }];
}

@end
