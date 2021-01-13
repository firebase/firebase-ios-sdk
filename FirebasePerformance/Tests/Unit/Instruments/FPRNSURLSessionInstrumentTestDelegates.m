// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Tests/Unit/Instruments/FPRNSURLSessionInstrumentTestDelegates.h"

@implementation FPRNSURLSessionTestDelegate

- (void)dealloc {
  [self didDealloc];
}

/** Exists to be found be OCMExpect. Does nothing. */
- (void)didDealloc {
}

- (void)didCallNonStandardDelegateMethod {
  self.nonStandardDelegateMethodCalled = YES;
}

// Used for a respondsToSelector check.
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
  self.URLSessionDidBecomeInvalidWithErrorWasCalled = YES;
}

@end

@implementation FPRNSURLSessionCompleteTestDelegate

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  self.URLSessionTaskDidCompleteWithErrorCalled = YES;
}

- (void)URLSession:(NSURLSession *)session
                        task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
  self.URLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedCalled = YES;
}

- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                    newRequest:(NSURLRequest *)request
             completionHandler:(void (^)(NSURLRequest *))completionHandler {
  self.URLSessionTaskWillPerformHTTPRedirectionNewRequestCompletionHandlerCalled = YES;
  if (completionHandler) {
    completionHandler(nil);
  };
}

#pragma mark - NSURLSessionDataDelegate methods

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
  self.URLSessionDataTaskDidReceiveDataCalled = YES;
}

#pragma mark - NSURLSessionDownloadDelegate methods

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
  self.URLSessionDownloadTaskDidFinishDownloadingToURLCalled = YES;
}

- (void)URLSession:(NSURLSession *)session
          downloadTask:(NSURLSessionDownloadTask *)downloadTask
     didResumeAtOffset:(int64_t)fileOffset
    expectedTotalBytes:(int64_t)expectedTotalBytes {
  self.URLSessionDownloadTaskDidResumeAtOffsetExpectedTotalBytesCalled = YES;
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  self.URLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesCalled = YES;
}

@end

@interface FPRNSURLSessionTestDownloadDelegate ()

// Redeclare as readwrite and mutable.
@property(nonatomic, readwrite) NSMutableData *dataWrittenThusFar;

@end

@implementation FPRNSURLSessionTestDownloadDelegate

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
  self.URLSessionDownloadTaskDidFinishDownloadingToURLCalled = YES;
}

- (void)URLSession:(NSURLSession *)session
          downloadTask:(NSURLSessionDownloadTask *)downloadTask
     didResumeAtOffset:(int64_t)fileOffset
    expectedTotalBytes:(int64_t)expectedTotalBytes {
  self.URLSessionDownloadTaskDidResumeAtOffsetExpectedTotalBytesCalled = YES;
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  if (bytesWritten > 0) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [downloadTask cancelByProducingResumeData:^(NSData *_Nullable resumeData) {
        // Create a resumable download task with the cancelled data, and start it.
        [[session downloadTaskWithResumeData:resumeData] resume];
      }];
    });
  }
  self.URLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesCalled = YES;
}

@end
