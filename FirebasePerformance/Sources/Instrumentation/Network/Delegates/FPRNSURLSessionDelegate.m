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

#pragma mark - Async/await support helpers

void FPRHandleDidCreateTask(NSURLSessionTask *task) {
  @try {
    // Skip if trace was already attached by the ObjC task creation swizzle path.
    if ([FPRNetworkTrace networkTraceFromObject:task] != nil) {
      return;
    }
    // Guard against nil request.
    if (!task.originalRequest) {
      return;
    }
    FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:task.originalRequest];
    [trace start];
    [FPRNetworkTrace addNetworkTrace:trace toObject:task];
  } @catch (NSException *exception) {
    FPRLogWarning(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
  }
}

void FPRHandleDidFinishCollectingMetrics(NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics) {
  @try {
    FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
    if (!trace) {
      return;
    }
    // Use task metrics for accurate byte counts (more reliable than incremental callbacks).
    NSURLSessionTaskTransactionMetrics *transactionMetrics = metrics.transactionMetrics.lastObject;
    if (transactionMetrics) {
      trace.responseSize = transactionMetrics.countOfResponseBodyBytesReceived;
      trace.requestSize = transactionMetrics.countOfRequestBodyBytesSent;
    }
    // Ensure intermediate checkpoints are recorded before completion.
    [trace checkpointState:FPRNetworkTraceCheckpointStateRequestCompleted];
    [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
    // Complete the trace. For ObjC delegate tasks this fires before didCompleteWithError:,
    // making that subsequent call a no op via the traceCompleted guard.
    [trace didCompleteRequestWithResponse:task.response error:task.error];
    [FPRNetworkTrace removeNetworkTraceFromObject:task];
  } @catch (NSException *exception) {
    FPRLogWarning(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
  }
}

@implementation FPRNSURLSessionDelegate

#pragma mark - Async/await support

/** Fires for every task created on the session, including tasks created by Swift async/await
 *  methods (iOS 16+). This is the only reliable hook that fires for async created tasks
 *  where delegate data transfer callbacks are suppressed by the system.
 *  Only creates a trace when one has not already been attached by the ObjC task creation swizzle.
 */
- (void)URLSession:(NSURLSession *)session
     didCreateTask:(NSURLSessionTask *)task API_AVAILABLE(ios(16.0), tvos(16.0)) {
  FPRHandleDidCreateTask(task);
}

/** Fires after every task completes (iOS 10+), including async/await created tasks where
 *  didCompleteWithError: is suppressed by the system. Using metrics also provides more accurate
 *  byte counts than incremental delegate callbacks.
 *  The traceCompleted guard inside FPRNetworkTrace ensures this is safe to call more than once.
 */
- (void)URLSession:(NSURLSession *)session
                          task:(NSURLSessionTask *)task
    didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics {
  FPRHandleDidFinishCollectingMetrics(task, metrics);
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
  @try {
    FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
    [trace didCompleteRequestWithResponse:task.response error:error];
    [FPRNetworkTrace removeNetworkTraceFromObject:task];
  } @catch (NSException *exception) {
    FPRLogWarning(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
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
      [trace checkpointState:FPRNetworkTraceCheckpointStateRequestCompleted];
    }
  } @catch (NSException *exception) {
    FPRLogWarning(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
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
