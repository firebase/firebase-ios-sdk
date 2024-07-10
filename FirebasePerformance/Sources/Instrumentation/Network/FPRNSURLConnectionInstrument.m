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

#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLConnectionInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLConnectionInstrument_Private.h"

#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/ISASwizzler/FPRObjectSwizzler.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRObjectInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/Delegates/FPRNSURLConnectionDelegate.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNetworkInstrumentHelpers.h"

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"

static NSString *const kFPRDelegateKey = @"kFPRDelegateKey";

typedef void (^FPRNSURLConnectionCompletionHandler)(NSURLResponse *_Nullable response,
                                                    NSData *_Nullable data,
                                                    NSError *_Nullable connectionError);

/** Returns the dispatch queue for all instrumentation to occur on. */
static dispatch_queue_t GetInstrumentationQueue(void) {
  static dispatch_queue_t queue = nil;
  static dispatch_once_t token = 0;
  dispatch_once(&token, ^{
    queue = dispatch_queue_create("com.google.FPRNSURLConnectionInstrumentation",
                                  DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

/** Instruments +sendAsynchronousRequest:queue:completionHandler:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentSendAsynchronousRequestQueueCompletionHandler(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(sendAsynchronousRequest:queue:completionHandler:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, YES);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor
      setReplacingBlock:^(id connection, NSURLRequest *request, NSOperationQueue *queue,
                          FPRNSURLConnectionCompletionHandler completionHandler) {
        FPRNetworkTrace *trace = [[FPRNetworkTrace alloc] initWithURLRequest:request];
        [trace start];
        [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];

        // The completionHandler needs to be there for FPRNetworkTrace purposes, even if originally
        // nil.
        FPRNSURLConnectionCompletionHandler wrappedCompletionHandler =
            ^(NSURLResponse *_Nullable response, NSData *_Nullable data,
              NSError *_Nullable connectionError) {
              [trace didReceiveData:data];
              [trace didCompleteRequestWithResponse:response error:connectionError];
              if (completionHandler) {
                completionHandler(response, data, connectionError);
              }
            };
        typedef void (*OriginalImp)(id, SEL, NSURLRequest *, NSOperationQueue *,
                                    FPRNSURLConnectionCompletionHandler);
        ((OriginalImp)currentIMP)(connection, selector, request, queue, wrappedCompletionHandler);
      }];
}

/** Instruments -initWithRequest:delegate:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 *  @param delegateInstrument The FPRNSURLConnectionDelegateInstrument to potentially add a new
 *      class to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentInitWithRequestDelegate(FPRClassInstrumentor *instrumentor,
                                       FPRNSURLConnectionDelegateInstrument *delegateInstrument) {
  SEL selector = @selector(initWithRequest:delegate:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;

  [selectorInstrumentor setReplacingBlock:^(id connection, NSURLRequest *request, id delegate) {
    if (delegate) {
      [delegateInstrument registerClass:[delegate class]];
      [delegateInstrument registerObject:delegate];
      [FPRObjectSwizzler setAssociatedObject:connection
                                         key:(__bridge const void *_Nonnull)kFPRDelegateKey
                                       value:delegate
                                 association:GUL_ASSOCIATION_ASSIGN];
    } else {
      delegate = [[FPRNSURLConnectionDelegate alloc] init];
      [FPRObjectSwizzler setAssociatedObject:connection
                                         key:(__bridge const void *_Nonnull)kFPRDelegateKey
                                       value:delegate
                                 association:GUL_ASSOCIATION_ASSIGN];
    }
    typedef NSURLConnection *(*OriginalImp)(id, SEL, NSURLRequest *, id);
    return ((OriginalImp)currentIMP)(connection, selector, request, delegate);
  }];
}

/** Instruments -initWithRequest:delegate:startImmediately:.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 *  @param delegateInstrument The FPRNSURLConnectionDelegateInstrument to potentially add a new
 *      class to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentInitWithRequestDelegateStartImmediately(
    FPRClassInstrumentor *instrumentor, FPRNSURLConnectionDelegateInstrument *delegateInstrument) {
  SEL selector = @selector(initWithRequest:delegate:startImmediately:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id connection, NSURLRequest *request, id delegate,
                                            BOOL startImmediately) {
    if (delegate) {
      [delegateInstrument registerClass:[delegate class]];
      [delegateInstrument registerObject:delegate];

      [FPRObjectSwizzler setAssociatedObject:connection
                                         key:(__bridge const void *_Nonnull)kFPRDelegateKey
                                       value:delegate
                                 association:GUL_ASSOCIATION_ASSIGN];
    } else {
      delegate = [[FPRNSURLConnectionDelegate alloc] init];
      [FPRObjectSwizzler setAssociatedObject:connection
                                         key:(__bridge const void *_Nonnull)kFPRDelegateKey
                                       value:delegate
                                 association:GUL_ASSOCIATION_ASSIGN];
    }
    typedef NSURLConnection *(*OriginalImp)(id, SEL, NSURLRequest *, id, BOOL);
    return ((OriginalImp)currentIMP)(connection, selector, request, delegate, startImmediately);
  }];
}

/** Instruments -start.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionStart(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(start);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id object) {
    typedef void (*OriginalImp)(id, SEL);
    NSURLConnection *connection = (NSURLConnection *)object;
    if ([FPRObjectSwizzler getAssociatedObject:connection
                                           key:(__bridge const void *_Nonnull)kFPRDelegateKey]) {
      FPRNetworkTrace *trace =
          [[FPRNetworkTrace alloc] initWithURLRequest:connection.originalRequest];
      [trace start];
      [trace checkpointState:FPRNetworkTraceCheckpointStateInitiated];
      [FPRNetworkTrace addNetworkTrace:trace toObject:connection];
    }
    ((OriginalImp)currentIMP)(connection, selector);
  }];
}

/** Instruments -cancel.
 *
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentConnectionCancel(FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(cancel);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP currentIMP = selectorInstrumentor.currentIMP;
  [selectorInstrumentor setReplacingBlock:^(id object) {
    typedef void (*OriginalImp)(id, SEL);
    NSURLConnection *connection = (NSURLConnection *)object;
    FPRNetworkTrace *trace = [FPRNetworkTrace networkTraceFromObject:connection];
    [trace didCompleteRequestWithResponse:nil error:nil];
    [FPRNetworkTrace removeNetworkTraceFromObject:connection];
    ((OriginalImp)currentIMP)(connection, selector);
  }];
}

@implementation FPRNSURLConnectionInstrument

- (instancetype)init {
  self = [super init];
  if (self) {
    _delegateInstrument = [[FPRNSURLConnectionDelegateInstrument alloc] init];
    [_delegateInstrument registerInstrumentors];
  }
  return self;
}

- (void)dealloc {
  [_delegateInstrument deregisterInstrumentors];
}

- (void)registerInstrumentors {
  dispatch_sync(GetInstrumentationQueue(), ^{
    FPRClassInstrumentor *instrumentor =
        [[FPRClassInstrumentor alloc] initWithClass:[NSURLConnection class]];

    if (![self registerClassInstrumentor:instrumentor]) {
      FPRAssert(NO, @"NSURLConnection should only be instrumented once.");
    }

    InstrumentSendAsynchronousRequestQueueCompletionHandler(instrumentor);

    InstrumentInitWithRequestDelegate(instrumentor, _delegateInstrument);
    InstrumentInitWithRequestDelegateStartImmediately(instrumentor, _delegateInstrument);

    InstrumentConnectionStart(instrumentor);
    InstrumentConnectionCancel(instrumentor);

    [instrumentor swizzle];
  });
}

- (void)deregisterInstrumentors {
  [_delegateInstrument deregisterInstrumentors];
  [super deregisterInstrumentors];
}

@end
