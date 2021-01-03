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

#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLSessionDelegate.h"

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"

@implementation FPRNSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  @try {
    FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
    [trace didCompleteRequestWithResponse:task.response error:error];
    [FPRNetworkTrace removeNetworkTraceFromObject:task];
  } @catch (NSException *exception) {
    FPRLogInfo(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
  }
}

- (void)URLSession:(NSURLSession *)session
                        task:(NSURLSessionTask *)task
             didSendBodyData:(int64_t)bytesSent
              totalBytesSent:(int64_t)totalBytesSent
    totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
  @try {
    FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
    trace.requestSize = totalBytesSent;
    if (totalBytesSent >= totalBytesExpectedToSend) {
      if ([task.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        [trace didCompleteRequestWithResponse:response error:task.error];
        [FPRNetworkTrace removeNetworkTraceFromObject:task];
      }
    }
  } @catch (NSException *exception) {
    FPRLogInfo(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
  }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:dataTask];
  [trace didReceiveData:data];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
    didFinishDownloadingToURL:(NSURL *)location {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:downloadTask];
  [trace didReceiveFileURL:location];
  [trace didCompleteRequestWithResponse:downloadTask.response error:downloadTask.error];
  [FPRNetworkTrace removeNetworkTraceFromObject:downloadTask];
}

- (void)URLSession:(NSURLSession *)session
                 downloadTask:(NSURLSessionDownloadTask *)downloadTask
                 didWriteData:(int64_t)bytesWritten
            totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:downloadTask];
  [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
  trace.responseSize = totalBytesWritten;
  if (totalBytesWritten >= totalBytesExpectedToWrite) {
    if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSHTTPURLResponse *response = (NSHTTPURLResponse *)downloadTask.response;
      [trace didCompleteRequestWithResponse:response error:downloadTask.error];
      [FPRNetworkTrace removeNetworkTraceFromObject:downloadTask];
    }
  }
}

@end
