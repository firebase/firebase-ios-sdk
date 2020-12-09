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

/** NSURLSession is a class cluster and the type of class you get back from the various
 *  initialization methods might not actually be NSURLSession. Inside those methods, this class
 *  keeps track of seen NSURLSession subclasses and lazily swizzles them if they've not been seen.
 *  Consequently, swizzling needs to occur on a serial queue for thread safety.
 */

#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLSessionInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLSessionInstrument_Private.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRProxyObjectHelper.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLSessionDelegate.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNetworkInstrumentHelpers.h"

#import <GoogleUtilities/GULObjectSwizzler.h>

// Declared for use in instrumentation functions below.
@interface FPRNSURLSessionInstrument ()

/** Registers an instrumentor for an NSURLSession subclass if it hasn't yet been instrumented.
 *
 *  @param aClass The class we wish to instrument.
 */
- (void)registerInstrumentorForClass:(Class)aClass;

/** Registers an instrumentor for an NSURLSession proxy object if it hasn't yet been instrumented.
 *
 *  @param proxy The proxy object we wish to instrument.
 */
- (void)registerProxyObject:(id)proxy;

@end

/** Returns the dispatch queue for all instrumentation to occur on. */
static dispatch_queue_t GetInstrumentationQueue() {
  static dispatch_queue_t queue = nil;
  static dispatch_once_t token = 0;
  dispatch_once(&token, ^{
    queue =
        dispatch_queue_create("com.google.FPRNSURLSessionInstrumentation", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

// This completion handler type is commonly used throughout NSURLSession.
typedef void (^FPRDataTaskCompletionHandler)(NSData *_Nullable,
                                             NSURLResponse *_Nullable,
                                             NSError *_Nullable);

typedef void (^FPRDownloadTaskCompletionHandler)(NSURL *_Nullable location,
                                                 NSURLResponse *_Nullable response,
                                                 NSError *_Nullable error);

#pragma mark - Instrumentation Functions

/** Wraps +sharedSession.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentSharedSession(FPRNSURLSessionInstrument *instrument,
                             FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(sharedSession);
  Class instrumentedClass = instrumentor.instrumentedClass;
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentedClass);
    }
    typedef NSURLSession *(*OriginalImp)(id, SEL);
    NSURLSession *sharedSession = ((OriginalImp)currentIMP)(session, selector);
    if ([sharedSession isProxy]) {
      [strongInstrument registerProxyObject:sharedSession];
    } else {
      [strongInstrument registerInstrumentorForClass:[sharedSession class]];
    }
    return sharedSession;
  }];
}

/** Wraps +sessionWithConfiguration:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentSessionWithConfiguration(FPRNSURLSessionInstrument *instrument,
                                        FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(sessionWithConfiguration:);
  Class instrumentedClass = instrumentor.instrumentedClass;
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLSessionConfiguration *configuration) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentedClass);
    }
    typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *);
    NSURLSession *sessionInstance = ((OriginalImp)currentIMP)(session, selector, configuration);
    if ([sessionInstance isProxy]) {
      [strongInstrument registerProxyObject:sessionInstance];
    } else {
      [strongInstrument registerInstrumentorForClass:[sessionInstance class]];
    }
    return sessionInstance;
  }];
}

/** Wraps +sessionWithConfiguration:delegate:delegateQueue:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 *  @param delegateInstrument The FPRNSURLSessionDelegateInstrument that will track the delegate
 *      selectors.
 */
FOUNDATION_STATIC_INLINE
void InstrumentSessionWithConfigurationDelegateDelegateQueue(
    FPRNSURLSessionInstrument *instrument,
    FPRClassInstrumentor *instrumentor,
    FPRNSURLSessionDelegateInstrument *delegateInstrument) {
  SEL selector = @selector(sessionWithConfiguration:delegate:delegateQueue:);
  Class instrumentedClass = instrumentor.instrumentedClass;
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor
      setReplacingBlock:^(id session, NSURLSessionConfiguration *configuration,
                          id<NSURLSessionDelegate> delegate, NSOperationQueue *queue) {
        __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
        if (!strongInstrument) {
          ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentedClass);
        }
        if (delegate) {
          [delegateInstrument registerClass:[delegate class]];
          [delegateInstrument registerObject:delegate];

        } else {
          delegate = [[FPRNSURLSessionDelegate alloc] init];
        }
        typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *,
                                             id<NSURLSessionDelegate>, NSOperationQueue *);
        NSURLSession *sessionInstance =
            ((OriginalImp)currentIMP)([session class], selector, configuration, delegate, queue);
        if ([sessionInstance isProxy]) {
          [strongInstrument registerProxyObject:sessionInstance];
        } else {
          [strongInstrument registerInstrumentorForClass:[sessionInstance class]];
        }
        return sessionInstance;
      }];
}

/** Wraps -dataTaskWithURL:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */

FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithURL(FPRNSURLSessionInstrument *instrument,
                               FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithURL:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *url) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURL *);
    NSURLSessionDataTask *dataTask = ((OriginalImp)currentIMP)(session, selector, url);
    if (dataTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:dataTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:dataTask];
    }

    return dataTask;
  }];
}

/** Instruments -dataTaskWithURL:completionHandler:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithURLCompletionHandler(FPRNSURLSessionInstrument *instrument,
                                                FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithURL:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *URL,
                                            FPRDataTaskCompletionHandler completionHandler) {
    __block NSURLSessionDataTask *task = nil;
    FPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        [FPRNetworkTrace removeNetworkTraceFromObject:task];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURL *, FPRDataTaskCompletionHandler);
    task = ((OriginalImp)currentIMP)(session, selector, URL, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([FPRNetworkTrace networkTraceFromObject:task] == nil) {
      FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:task.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:task];
    }
    return task;
  }];
}

/** Wraps -dataTaskWithRequest:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */

FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithRequest(FPRNSURLSessionInstrument *instrument,
                                   FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithRequest:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    NSURLSessionDataTask *dataTask = ((OriginalImp)currentIMP)(session, selector, request);
    if (dataTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:dataTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:dataTask];
    }

    return dataTask;
  }];
}

/** Instruments -dataTaskWithRequest:completionHandler:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDataTaskWithRequestCompletionHandler(FPRNSURLSessionInstrument *instrument,
                                                    FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(dataTaskWithRequest:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request,
                                            FPRDataTaskCompletionHandler completionHandler) {
    __block NSURLSessionDataTask *task = nil;
    FPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:task];
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        [FPRNetworkTrace removeNetworkTraceFromObject:task];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *,
                                                 FPRDataTaskCompletionHandler);
    task = ((OriginalImp)currentIMP)(session, selector, request, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([FPRNetworkTrace networkTraceFromObject:task] == nil) {
      FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:task.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:task];
    }
    return task;
  }];
}

/** Instruments -uploadTaskWithRequest:fromFile:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromFile(FPRNSURLSessionInstrument *instrument,
                                             FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromFile:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSURL *fileURL) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSURL *);
    NSURLSessionUploadTask *uploadTask =
        ((OriginalImp)currentIMP)(session, selector, request, fileURL);
    if (uploadTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:uploadTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:uploadTask];
    }
    return uploadTask;
  }];
}

/** Instruments -uploadTaskWithRequest:fromFile:completionHandler:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromFileCompletionHandler(FPRNSURLSessionInstrument *instrument,
                                                              FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromFile:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSURL *fileURL,
                                            FPRDataTaskCompletionHandler completionHandler) {
    FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:request];
    [trace start];
    [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
    [trace didUploadFileWithURL:fileURL];
    FPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSURL *,
                                                   FPRDataTaskCompletionHandler);
    return ((OriginalImp)currentIMP)(session, selector, request, fileURL, wrappedCompletionHandler);
  }];
}

/** Instruments -uploadTaskWithRequest:fromData:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromData(FPRNSURLSessionInstrument *instrument,
                                             FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromData:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSData *bodyData) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSData *);
    NSURLSessionUploadTask *uploadTask =
        ((OriginalImp)currentIMP)(session, selector, request, bodyData);
    if (uploadTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:uploadTask.originalRequest];
      [trace start];
      trace.requestSize = bodyData.length;
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:uploadTask];
    }
    return uploadTask;
  }];
}

/** Instruments -uploadTaskWithRequest:fromData:completionHandler:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithRequestFromDataCompletionHandler(FPRNSURLSessionInstrument *instrument,
                                                              FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithRequest:fromData:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request, NSData *bodyData,
                                            FPRDataTaskCompletionHandler completionHandler) {
    FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:request];
    [trace start];
    trace.requestSize = bodyData.length;
    [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
    FPRDataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        [trace didReceiveData:data];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *, NSData *,
                                                   FPRDataTaskCompletionHandler);
    return ((OriginalImp)currentIMP)(session, selector, request, bodyData,
                                     wrappedCompletionHandler);
  }];
}

/** Instruments -uploadTaskWithStreamedRequest:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentUploadTaskWithStreamedRequest(FPRNSURLSessionInstrument *instrument,
                                             FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(uploadTaskWithStreamedRequest:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionUploadTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    NSURLSessionUploadTask *uploadTask = ((OriginalImp)currentIMP)(session, selector, request);
    if (uploadTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:uploadTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:uploadTask];
    }
    return uploadTask;
  }];
}

/** Instruments -downloadTaskWithURL:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithURL(FPRNSURLSessionInstrument *instrument,
                                   FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithURL:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *url) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURL *);
    NSURLSessionDownloadTask *downloadTask = ((OriginalImp)currentIMP)(session, selector, url);
    if (downloadTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

/** Instruments -downloadTaskWithURL:completionHandler:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithURLCompletionHandler(FPRNSURLSessionInstrument *instrument,
                                                    FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithURL:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURL *URL,
                                            FPRDownloadTaskCompletionHandler completionHandler) {
    __block NSURLSessionDownloadTask *downloadTask = nil;
    FPRDownloadTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSURL *location, NSURLResponse *response, NSError *error) {
        FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:downloadTask];
        [trace didReceiveFileURL:location];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(location, response, error);
      };
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURL *,
                                                     FPRDownloadTaskCompletionHandler);
    downloadTask = ((OriginalImp)currentIMP)(session, selector, URL, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([FPRNetworkTrace networkTraceFromObject:downloadTask] == nil) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

/** Instruments -downloadTaskWithRequest:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithRequest(FPRNSURLSessionInstrument *instrument,
                                       FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithRequest:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  __weak FPRNSURLSessionInstrument *weakInstrument = instrument;
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    __strong FPRNSURLSessionInstrument *strongInstrument = weakInstrument;
    if (!strongInstrument) {
      ThrowExceptionBecauseInstrumentHasBeenDeallocated(selector, instrumentor.instrumentedClass);
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    NSURLSessionDownloadTask *downloadTask = ((OriginalImp)currentIMP)(session, selector, request);
    if (downloadTask.originalRequest) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

/** Instruments -downloadTaskWithRequest:completionHandler:.
 *
 *  @param instrument The FPRNSURLSessionInstrument instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
void InstrumentDownloadTaskWithRequestCompletionHandler(FPRNSURLSessionInstrument *instrument,
                                                        FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(downloadTaskWithRequest:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id session, NSURLRequest *request,
                                            FPRDownloadTaskCompletionHandler completionHandler) {
    __block NSURLSessionDownloadTask *downloadTask = nil;
    FPRDownloadTaskCompletionHandler wrappedCompletionHandler = nil;

    if (completionHandler) {
      wrappedCompletionHandler = ^(NSURL *location, NSURLResponse *response, NSError *error) {
        FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:downloadTask];
        [trace didReceiveFileURL:location];
        [trace didCompleteRequestWithResponse:response error:error];
        completionHandler(location, response, error);
      };
    }
    typedef NSURLSessionDownloadTask *(*OriginalImp)(id, SEL, NSURLRequest *,
                                                     FPRDownloadTaskCompletionHandler);
    downloadTask = ((OriginalImp)currentIMP)(session, selector, request, wrappedCompletionHandler);

    // Add the network trace object only when the trace object is not added to the task object.
    if ([FPRNetworkTrace networkTraceFromObject:downloadTask] == nil) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:downloadTask.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:downloadTask];
    }
    return downloadTask;
  }];
}

#pragma mark - FPRNSURLSessionInstrument

@implementation FPRNSURLSessionInstrument

- (instancetype)init {
  self = [super init];
  if (self) {
    _delegateInstrument = [[FPRNSURLSessionDelegateInstrument alloc] init];
    [_delegateInstrument registerInstrumentors];
  }
  return self;
}

- (void)registerInstrumentors {
  [self registerInstrumentorForClass:[NSURLSession class]];
}

- (void)deregisterInstrumentors {
  [_delegateInstrument deregisterInstrumentors];
  [super deregisterInstrumentors];
}

- (void)registerInstrumentorForClass:(Class)aClass {
  dispatch_sync(GetInstrumentationQueue(), ^{
    FPRAssert([aClass isSubclassOfClass:[NSURLSession class]],
              @"Class %@ is not a subclass of "
               "NSURLSession",
              aClass);
    // If this class has already been instrumented, just return.
    FPRClassInstrumentor *instrumentor = [[FPRClassInstrumentor alloc] initWithClass:aClass];
    if (![self registerClassInstrumentor:instrumentor]) {
      return;
    }

    InstrumentSharedSession(self, instrumentor);

    InstrumentSessionWithConfiguration(self, instrumentor);
    InstrumentSessionWithConfigurationDelegateDelegateQueue(self, instrumentor,
                                                            _delegateInstrument);

    InstrumentDataTaskWithURL(self, instrumentor);
    InstrumentDataTaskWithURLCompletionHandler(self, instrumentor);
    InstrumentDataTaskWithRequest(self, instrumentor);
    InstrumentDataTaskWithRequestCompletionHandler(self, instrumentor);

    InstrumentUploadTaskWithRequestFromFile(self, instrumentor);
    InstrumentUploadTaskWithRequestFromFileCompletionHandler(self, instrumentor);
    InstrumentUploadTaskWithRequestFromData(self, instrumentor);
    InstrumentUploadTaskWithRequestFromDataCompletionHandler(self, instrumentor);
    InstrumentUploadTaskWithStreamedRequest(self, instrumentor);

    InstrumentDownloadTaskWithURL(self, instrumentor);
    InstrumentDownloadTaskWithURLCompletionHandler(self, instrumentor);
    InstrumentDownloadTaskWithRequest(self, instrumentor);
    InstrumentDownloadTaskWithRequestCompletionHandler(self, instrumentor);

    [instrumentor swizzle];
  });
}

- (void)registerProxyObject:(id)proxy {
  [FPRProxyObjectHelper registerProxyObject:proxy
                              forSuperclass:[NSURLSession class]
                            varFoundHandler:^(id ivar) {
                              [self registerInstrumentorForClass:[ivar class]];
                            }];
}

@end
