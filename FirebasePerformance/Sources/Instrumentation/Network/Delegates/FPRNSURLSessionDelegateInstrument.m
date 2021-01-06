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

#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLSessionDelegateInstrument.h"

#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLSessionDelegate.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNetworkInstrumentHelpers.h"

/** Returns the dispatch queue for all instrumentation to occur on. */
static dispatch_queue_t GetInstrumentationQueue() {
  static dispatch_queue_t queue;
  static dispatch_once_t token;
  dispatch_once(&token, ^{
    queue = dispatch_queue_create("com.google.FPRNSURLSessionDelegateInstrument",
                                  DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

#pragma mark - NSURLSessionTaskDelegate methods

/** Instruments URLSession:task:didCompleteWithError:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentURLSessionTaskDidCompleteWithError(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(URLSession:task:didCompleteWithError:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor setReplacingBlock:^(id object, NSURLSession *session,
                                              NSURLSessionTask *task, NSError *error) {
      @try {
        FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
        [trace didCompleteRequestWithResponse:task.response error:error];
        [FPRNetworkTrace removeNetworkTraceFromObject:task];
      } @catch (NSException *exception) {
        FPRLogInfo(kFPRNetworkTraceNotTrackable, @"Unable to track network request.");
      } @finally {
        typedef void (*OriginalImp)(id, SEL, NSURLSession *, NSURLSessionTask *, NSError *);
        ((OriginalImp)currentIMP)(object, selector, session, task, error);
      }
    }];
  }
}

/** Instruments URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentURLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedToSend(
    FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(URLSession:
                                 task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLSession *session, NSURLSessionTask *task,
                            int64_t bytesSent, int64_t totalBytesSent,
                            int64_t totalBytesExpectedToSend) {
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
          } @finally {
            typedef void (*OriginalImp)(id, SEL, NSURLSession *, NSURLSessionTask *, int64_t,
                                        int64_t, int64_t);
            ((OriginalImp)currentIMP)(object, selector, session, task, bytesSent, totalBytesSent,
                                      totalBytesExpectedToSend);
          }
        }];
  }
}

#pragma mark - NSURLSessionDataDelegate methods

/** Instruments URLSession:dataTask:didReceiveData:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentURLSessionDataTaskDidReceiveData(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(URLSession:dataTask:didReceiveData:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor setReplacingBlock:^(id object, NSURLSession *session,
                                              NSURLSessionDataTask *dataTask, NSData *data) {
      FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:dataTask];
      [trace didReceiveData:data];
      [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
      typedef void (*OriginalImp)(id, SEL, NSURLSession *, NSURLSessionDataTask *, NSData *);
      ((OriginalImp)currentIMP)(object, selector, session, dataTask, data);
    }];
  }
}

#pragma mark - NSURLSessionDownloadDelegate methods.

/** Instruments URLSession:downloadTask:didFinishDownloadingToURL:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentURLSessionDownloadTaskDidFinishDownloadToURL(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(URLSession:downloadTask:didFinishDownloadingToURL:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLSession *session,
                            NSURLSessionDownloadTask *downloadTask, NSURL *location) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:downloadTask];
          [trace didReceiveFileURL:location];
          [trace didCompleteRequestWithResponse:downloadTask.response error:downloadTask.error];
          [FPRNetworkTrace removeNetworkTraceFromObject:downloadTask];
          typedef void (*OriginalImp)(id, SEL, NSURLSession *, NSURLSessionDownloadTask *, NSURL *);
          ((OriginalImp)currentIMP)(object, selector, session, downloadTask, location);
        }];
  }
}

/** Instruments URLSession:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentURLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesExpectedToWrite(
    FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(URLSession:
                         downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLSession *session,
                            NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten,
                            int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
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
          typedef void (*OriginalImp)(id, SEL, NSURLSession *, NSURLSessionDownloadTask *, int64_t,
                                      int64_t, int64_t);
          ((OriginalImp)currentIMP)(object, selector, session, downloadTask, bytesWritten,
                                    totalBytesWritten, totalBytesExpectedToWrite);
        }];
  }
}

#pragma mark - Helper functions

FOUNDATION_STATIC_INLINE
void CopySelector(SEL selector, FPRObjectInstrumentor *instrumentor) {
  static Class fromClass = Nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    fromClass = [FPRNSURLSessionDelegate class];
  });
  if (![instrumentor.instrumentedObject respondsToSelector:selector]) {
    [instrumentor copySelector:selector fromClass:fromClass isClassSelector:NO];
  }
}

#pragma mark - FPRNSURLSessionDelegateInstrument

@implementation FPRNSURLSessionDelegateInstrument

- (void)registerInstrumentors {
  // Do nothing by default; classes will be instrumented on-demand upon discovery.
}

- (void)registerClass:(Class)aClass {
  dispatch_sync(GetInstrumentationQueue(), ^{
    // If this class has already been instrumented, just return.
    FPRClassInstrumentor *instrumentor = [[FPRClassInstrumentor alloc] initWithClass:aClass];
    if (![self registerClassInstrumentor:instrumentor]) {
      return;
    }

    // NSURLSessionTaskDelegate methods.
    InstrumentURLSessionTaskDidCompleteWithError(instrumentor);
    InstrumentURLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedToSend(instrumentor);

    // NSURLSessionDataDelegate methods.
    InstrumentURLSessionDataTaskDidReceiveData(instrumentor);

    // NSURLSessionDownloadDelegate methods.
    InstrumentURLSessionDownloadTaskDidFinishDownloadToURL(instrumentor);
    InstrumentURLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesExpectedToWrite(
        instrumentor);

    [instrumentor swizzle];
  });
}

- (void)registerObject:(id)object {
  dispatch_sync(GetInstrumentationQueue(), ^{
    if ([object respondsToSelector:@selector(gul_class)]) {
      return;
    }
    FPRObjectInstrumentor *instrumentor = [[FPRObjectInstrumentor alloc] initWithObject:object];

    // Register the non-swizzled versions of these methods.
    // NSURLSessionTaskDelegate methods.
    CopySelector(@selector(URLSession:task:didCompleteWithError:), instrumentor);
    CopySelector(@selector(URLSession:
                                 task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:),
                 instrumentor);

    // NSURLSessionDataDelegate methods.
    CopySelector(@selector(URLSession:dataTask:didReceiveData:), instrumentor);

    // NSURLSessionDownloadDelegate methods.
    CopySelector(@selector(URLSession:downloadTask:didFinishDownloadingToURL:), instrumentor);
    CopySelector(@selector(URLSession:downloadTask:didResumeAtOffset:expectedTotalBytes:),
                 instrumentor);
    CopySelector(@selector(URLSession:
                         downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:),
                 instrumentor);

    [instrumentor swizzle];
  });
}

@end
