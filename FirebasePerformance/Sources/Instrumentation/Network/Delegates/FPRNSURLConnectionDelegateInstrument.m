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

#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLConnectionDelegateInstrument.h"

#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLConnectionDelegate.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNetworkInstrumentHelpers.h"

#pragma mark - NSURLConnectionDelegate methods

/** Returns the dispatch queue for all instrumentation to occur on. */
static dispatch_queue_t GetInstrumentationQueue(void) {
  static dispatch_queue_t queue;
  static dispatch_once_t token;
  dispatch_once(&token, ^{
    queue = dispatch_queue_create("com.google.FPRNSURLConnectionDelegateInstrument",
                                  DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

/** Instruments connection:didFailWithError:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionDidFailWithError(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connection:didFailWithError:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLConnection *connection, NSError *error) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
          [trace didCompleteRequestWithResponse:nil error:error];
          [FPRNetworkTrace removeNetworkTraceFromObject:connection];
          typedef void (*OriginalImp)(id, SEL, NSURLConnection *, NSError *);
          ((OriginalImp)currentIMP)(object, selector, connection, error);
        }];
  }
}

#pragma mark - NSURLConnectionDataDelegate methods

/** Instruments connection:willSendRequest:redirectResponse:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionWillSendRequestRedirectResponse(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connection:willSendRequest:redirectResponse:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor setReplacingBlock:^(id object, NSURLConnection *connection,
                                              NSURLRequest *request, NSURLResponse *response) {
      FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
      [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
      typedef NSURLRequest *(*OriginalImp)(id, SEL, NSURLConnection *, NSURLRequest *,
                                           NSURLResponse *);
      return ((OriginalImp)currentIMP)(object, selector, connection, request, response);
    }];
  }
}

/** Instruments connection:didReceiveResponse:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionDidReceiveResponse(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connection:didReceiveResponse:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLConnection *connection, NSURLResponse *response) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
          if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            trace.responseCode = (int32_t)((NSHTTPURLResponse *)response).statusCode;
          }
          [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
          typedef void (*OriginalImp)(id, SEL, NSURLConnection *, NSURLResponse *);
          ((OriginalImp)currentIMP)(object, selector, connection, response);
        }];
  }
}

/** Instruments connection:didReceiveData:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionDidReceiveData(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connection:didReceiveData:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLConnection *connection, NSData *data) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
          [trace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
          trace.responseSize += data.length;
          typedef void (*OriginalImp)(id, SEL, NSURLConnection *, NSData *);
          ((OriginalImp)currentIMP)(object, selector, connection, data);
        }];
  }
}

/** Instruments connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionAllTheTotals(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLConnection *connection, NSInteger bytesWritten,
                            NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
          trace.requestSize = totalBytesWritten;
          if (totalBytesWritten >= totalBytesExpectedToWrite) {
            [trace checkpointState:FPRNetworkTraceCheckpointStateRequestCompleted];
          }
          typedef void (*OriginalImp)(id, SEL, NSURLConnection *, NSInteger, NSInteger, NSInteger);
          ((OriginalImp)currentIMP)(object, selector, connection, bytesWritten, totalBytesWritten,
                                    totalBytesExpectedToWrite);
        }];
  }
}

/** Instruments connectionDidFinishLoading:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionDidFinishLoading(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connectionDidFinishLoading:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor setReplacingBlock:^(id object, NSURLConnection *connection) {
      FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
      [trace didCompleteRequestWithResponse:nil error:nil];
      [FPRNetworkTrace removeNetworkTraceFromObject:connection];
      typedef void (*OriginalImp)(id, SEL, NSURLConnection *);
      ((OriginalImp)currentIMP)(object, selector, connection);
    }];
  }
}

/** Instruments connection:didWriteData:totalBytesWritten:expectedTotalBytes:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionDidWriteDataTotalBytesWrittenExpectedTotalBytes(
    FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connection:didWriteData:totalBytesWritten:expectedTotalBytes:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLConnection *connection, long long bytesWritten,
                            long long totalBytesWritten, long long expectedTotalBytes) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
          trace.requestSize = totalBytesWritten;
          typedef void (*OriginalImp)(id, SEL, NSURLConnection *, long long, long long, long long);
          ((OriginalImp)currentIMP)(object, selector, connection, bytesWritten, totalBytesWritten,
                                    expectedTotalBytes);
        }];
  }
}

/** Instruments connectionDidFinishDownloading:destinationURL:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionDidFinishDownloadingDestinationURL(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(connectionDidFinishDownloading:destinationURL:);
  FPRSelectorInstrumentor *selectorInstrumentor =
      [instrumentor instrumentorForInstanceSelector:selector];
  if (selectorInstrumentor) {
    IMP currentIMP = selectorInstrumentor.currentIMP;
    [selectorInstrumentor
        setReplacingBlock:^(id object, NSURLConnection *connection, NSURL *destinationURL) {
          FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
          [trace didReceiveFileURL:destinationURL];
          [trace didCompleteRequestWithResponse:nil error:nil];
          [FPRNetworkTrace removeNetworkTraceFromObject:connection];
          typedef void (*OriginalImp)(id, SEL, NSURLConnection *, NSURL *);
          ((OriginalImp)currentIMP)(object, selector, connection, destinationURL);
        }];
  }
}

#pragma mark - Helper functions
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void CopySelector(SEL selector, FPRObjectInstrumentor *instrumentor) {
  static Class fromClass = Nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    fromClass = [FPRNSURLConnectionDelegate class];
  });
  if (![instrumentor.instrumentedObject respondsToSelector:selector]) {
    [instrumentor copySelector:selector fromClass:fromClass isClassSelector:NO];
  }
}

#pragma mark - FPRNSURLConnectionDelegateInstrument

@implementation FPRNSURLConnectionDelegateInstrument

- (void)registerInstrumentors {
  // Do nothing by default. classes will be instrumented on-demand upon discovery.
}

- (void)registerClass:(Class)aClass {
  dispatch_sync(GetInstrumentationQueue(), ^{
    // If this class has already been instrumented, just return.
    FPRClassInstrumentor *instrumentor = [[FPRClassInstrumentor alloc] initWithClass:aClass];
    if (![self registerClassInstrumentor:instrumentor]) {
      return;
    }

    InstrumentConnectionDidFailWithError(instrumentor);
    InstrumentConnectionWillSendRequestRedirectResponse(instrumentor);
    InstrumentConnectionDidReceiveResponse(instrumentor);
    InstrumentConnectionDidReceiveData(instrumentor);
    InstrumentConnectionAllTheTotals(instrumentor);
    InstrumentConnectionDidFinishLoading(instrumentor);
    InstrumentConnectionDidWriteDataTotalBytesWrittenExpectedTotalBytes(instrumentor);
    InstrumentConnectionDidFinishDownloadingDestinationURL(instrumentor);

    [instrumentor swizzle];
  });
}

- (void)registerObject:(id)object {
  dispatch_sync(GetInstrumentationQueue(), ^{
    if ([object respondsToSelector:@selector(gul_class)]) {
      return;
    }

    if (![self isObjectInstrumentable:object]) {
      return;
    }

    FPRObjectInstrumentor *instrumentor = [[FPRObjectInstrumentor alloc] initWithObject:object];

    // Register the non-swizzled versions of these methods.
    CopySelector(@selector(connection:didFailWithError:), instrumentor);
    CopySelector(@selector(connection:willSendRequest:redirectResponse:), instrumentor);
    CopySelector(@selector(connection:didReceiveResponse:), instrumentor);
    CopySelector(@selector(connection:didReceiveData:), instrumentor);
    CopySelector(@selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:),
                 instrumentor);
    if (![object respondsToSelector:@selector(connectionDidFinishDownloading:destinationURL:)]) {
      CopySelector(@selector(connectionDidFinishLoading:), instrumentor);
    }

    CopySelector(@selector(connection:didWriteData:totalBytesWritten:expectedTotalBytes:),
                 instrumentor);
    if (![object respondsToSelector:@selector(connectionDidFinishLoading:)]) {
      CopySelector(@selector(connectionDidFinishDownloading:destinationURL:), instrumentor);
    }

    [instrumentor swizzle];
  });
}

@end
