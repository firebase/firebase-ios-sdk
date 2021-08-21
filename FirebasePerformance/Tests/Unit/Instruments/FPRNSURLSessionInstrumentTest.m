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

#pragma mark - Unswizzle based tests

#ifndef SWIFT_PACKAGE

#import "FirebasePerformance/Tests/Unit/Instruments/FPRNSURLSessionInstrumentTestDelegates.h"

#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLSessionInstrument.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLSessionInstrument_Private.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"
#import "FirebasePerformance/Tests/Unit/Server/FPRHermeticTestServer.h"

/** This class is used to wrap an NSURLSession object during testing. */
@interface FPRNSURLSessionProxy : NSProxy {
  // The wrapped session object.
  id _session;
}

/** @return an instance of the session proxy. */
- (instancetype)initWithSession:(id)session;

@end

@implementation FPRNSURLSessionProxy

- (instancetype)initWithSession:(id)session {
  if (self) {
    _session = session;
  }
  return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
  return [_session methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
  [invocation invokeWithTarget:_session];
}

@end

@interface FPRNSURLSessionInstrumentTest : FPRTestCase

/** Test server to create connections to. */
@property(nonatomic) FPRHermeticTestServer *testServer;

@end

@implementation FPRNSURLSessionInstrumentTest

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
  XCTAssertFalse(self.testServer.isRunning);
  self.testServer = [[FPRHermeticTestServer alloc] init];
  [self.testServer registerTestPaths];
  [self.testServer start];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  [self.testServer stop];
  [FPRConfigurations reset];
}

/** Waits for the server connection to finish by giving a block to run just before a response is
 * sent.
 *
 * @param block A block to run just after the server response is sent.
 */
- (void)waitAndRunBlockAfterResponse:(void (^)(id self,
                                               GCDWebServerRequest *_Nonnull request,
                                               GCDWebServerResponse *_Nonnull response))block {
  __block BOOL loopingMainThread = YES;
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __weak id weakSelf = self;
    self.testServer.responseCompletedBlock =
        ^(GCDWebServerRequest *_Nonnull request, GCDWebServerResponse *_Nonnull response) {
          block(weakSelf, request, response);
          dispatch_semaphore_signal(sema);
        };
    XCTAssertEqual(
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC)), 0);
    loopingMainThread = NO;
  });
  // This is necessary because the FPRHermeticTestServer callbacks occur on the main thread.
  while (loopingMainThread) {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
}

#pragma mark - Testing infrastructure and subclass instrumenting

/** Tests initing of FPRNSURLSessionInstrument also inits NSURLSessionDelegate instrument. */
- (void)testInit {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  self.testServer.responseCompletedBlock =
      ^(GCDWebServerRequest *_Nonnull request, GCDWebServerResponse *_Nonnull response) {
        XCTAssert(instrument);
        XCTAssert(instrument.delegateInstrument);
      };
  [instrument deregisterInstrumentors];
}

/** Tests that creating a shared session returns a non-nil object. */
- (void)testSharedSession {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  XCTAssertNotNil(session);
  [instrument deregisterInstrumentors];
}

/** Tests that a method that returns an NSURLSession subclass registers that subclass. */
- (void)testSubclassRegistration {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  XCTAssertNotNil(session);
  XCTAssertEqual(instrument.classInstrumentors.count, 2);
  [instrument deregisterInstrumentors];
}

/** Tests that a discovered subclass isn't registered more than once. */
- (void)testSubclassIsNotRegisteredMoreThanOnce {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSession *session2 = [NSURLSession sharedSession];
  XCTAssertNotNil(session);
  XCTAssertNotNil(session2);
  XCTAssertEqual(instrument.classInstrumentors.count, 2);
  [instrument deregisterInstrumentors];
}

/** Tests sessionWithConfiguration: with the default configurtion returns a non-nil object. */
- (void)testSessionWithDefaultSessionConfiguration {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  XCTAssertNotNil(session);
  XCTAssertEqual(instrument.classInstrumentors.count, 2);
  [instrument deregisterInstrumentors];
}

/** Tests sessionWithConfiguration: with an ephemeral configuration returns a non-nil object. */
- (void)testSessionWithEphemeralSessionConfiguration {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration ephemeralSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  XCTAssertNotNil(session);
  XCTAssertEqual(instrument.classInstrumentors.count, 2);
  [instrument deregisterInstrumentors];
}

/** Tests sessionWithConfiguration: with a background configuration returns a non-nil object. */
- (void)testSessionWithBackgroundSessionConfiguration {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"madeUpID"];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  XCTAssertNotNil(session);
  XCTAssertEqual(instrument.classInstrumentors.count, 2);
  [instrument deregisterInstrumentors];
}

/** Tests instrumenting an NSProxy wrapped NSURLSession object works. */
- (void)testProxyWrappedSharedSession {
  Method method = class_getClassMethod([NSURLSession class], @selector(sharedSession));
  IMP originalImp = method_getImplementation(method);
  IMP swizzledImp = imp_implementationWithBlock(^(id session) {
    typedef NSURLSession *(*OriginalImp)(id, SEL);
    NSURLSession *originalSession = ((OriginalImp)originalImp)(session, @selector(sharedSession));
    return [[FPRNSURLSessionProxy alloc] initWithSession:originalSession];
  });
  method_setImplementation(method, swizzledImp);
  XCTAssertEqual([[NSURLSession sharedSession] class], [FPRNSURLSessionProxy class]);
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session;
  XCTAssertNoThrow(session = [NSURLSession sharedSession]);
  NSURL *url = self.testServer.serverURL;
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler"];
  NSURLSessionDownloadTask *task =
      [session downloadTaskWithURL:url
                 completionHandler:^(NSURL *_Nullable location, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   [expectation fulfill];
                 }];
  [task resume];
  XCTAssertNotNil(task);
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
  method_setImplementation(method, originalImp);
  XCTAssertNotEqual([[NSURLSession sharedSession] class], [FPRNSURLSessionProxy class]);
}

/** Tests instrumenting an NSProxy wrapped NSURLSession object works. */
- (void)testProxyWrappedSessionWithConfiguration {
  Method method = class_getClassMethod([NSURLSession class], @selector(sessionWithConfiguration:));
  IMP originalImp = method_getImplementation(method);
  IMP swizzledImp =
      imp_implementationWithBlock(^(id session, NSURLSessionConfiguration *configuration) {
        typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *);
        NSURLSession *originalSession = ((OriginalImp)originalImp)(
            session, @selector(sessionWithConfiguration:), configuration);
        return [[FPRNSURLSessionProxy alloc] initWithSession:originalSession];
      });
  method_setImplementation(method, swizzledImp);
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
  XCTAssertEqual([[NSURLSession sessionWithConfiguration:config] class],
                 [FPRNSURLSessionProxy class]);
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session;
  XCTAssertNoThrow(session = [NSURLSession sessionWithConfiguration:config]);
  NSURL *url = self.testServer.serverURL;
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler"];
  NSURLSessionDownloadTask *task =
      [session downloadTaskWithURL:url
                 completionHandler:^(NSURL *_Nullable location, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   [expectation fulfill];
                 }];
  XCTAssertNotNil(task);
  [task resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
  method_setImplementation(method, originalImp);
  XCTAssertNotEqual([[NSURLSession sharedSession] class], [FPRNSURLSessionProxy class]);
}

/** Tests instrumenting an NSProxy wrapped NSURLSession object works. */
- (void)testProxyWrappedSessionWithConfigurationDelegateDelegateQueue {
  SEL selector = @selector(sessionWithConfiguration:delegate:delegateQueue:);
  Method method = class_getClassMethod([NSURLSession class], selector);
  IMP originalImp = method_getImplementation(method);
  IMP swizzledImp = imp_implementationWithBlock(
      ^(id session, NSURLSessionConfiguration *configuration, id<NSURLSessionDelegate> *delegate,
        NSOperationQueue *delegateQueue) {
        typedef NSURLSession *(*OriginalImp)(id, SEL, NSURLSessionConfiguration *,
                                             id<NSURLSessionDelegate> *, NSOperationQueue *);
        NSURLSession *originalSession =
            ((OriginalImp)originalImp)(session, selector, configuration, delegate, delegateQueue);
        return [[FPRNSURLSessionProxy alloc] initWithSession:originalSession];
      });
  method_setImplementation(method, swizzledImp);
  NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
  XCTAssertEqual([[NSURLSession sessionWithConfiguration:config delegate:nil
                                           delegateQueue:nil] class],
                 [FPRNSURLSessionProxy class]);
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session;
  XCTAssertNoThrow(session = [NSURLSession sessionWithConfiguration:config
                                                           delegate:nil
                                                      delegateQueue:nil]);
  NSURL *url = self.testServer.serverURL;
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler"];
  NSURLSessionDownloadTask *task =
      [session downloadTaskWithURL:url
                 completionHandler:^(NSURL *_Nullable location, NSURLResponse *_Nullable response,
                                     NSError *_Nullable error) {
                   [expectation fulfill];
                 }];
  XCTAssertNotNil(task);
  [task resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
  method_setImplementation(method, originalImp);
}

#pragma mark - Testing delegate method wrapping

/** Tests using a nil delegate still results in tracking responses. */
- (void)testSessionWithConfigurationDelegateDelegateQueueWithNilDelegate {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:nil
                                                   delegateQueue:nil];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  NSURLSessionTask *task;
  @autoreleasepool {
    task = [session dataTaskWithRequest:request];
    XCTAssertNotNil(task);
    [task resume];
    XCTAssertNotNil(session.delegate);  // Not sure this is the desired behavior.
    XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:task]);
    [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                         GCDWebServerResponse *_Nonnull response) {
      XCTAssertNil([FPRNetworkTrace networkTraceFromObject:task]);
    }];
  }
  [instrument deregisterInstrumentors];
}

/** Tests that the delegate class isn't instrumented more than once. */
- (void)testDelegateClassOnlyRegisteredOnce {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionCompleteTestDelegate *delegate =
      [[FPRNSURLSessionCompleteTestDelegate alloc] init];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
  [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
  XCTAssertEqual(instrument.delegateInstrument.classInstrumentors.count, 1);
  XCTAssertEqual(instrument.delegateInstrument.instrumentedClasses.count, 1);
  [instrument deregisterInstrumentors];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionTaskDidCompleteWithError {
  [self.testServer stop];
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionCompleteTestDelegate *delegate =
      [[FPRNSURLSessionCompleteTestDelegate alloc] init];
  // This request needs to fail.
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://nonurl"]];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  NSURLSessionTask *task;
  @autoreleasepool {
    task = [session dataTaskWithRequest:request];
    [task resume];
    XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:task]);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
  }
  XCTAssertNil([FPRNetworkTrace networkTraceFromObject:task]);
  XCTAssertTrue(delegate.URLSessionTaskDidCompleteWithErrorCalled);
  [instrument deregisterInstrumentors];
  [self.testServer start];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedToSend {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionCompleteTestDelegate *delegate =
      [[FPRNSURLSessionCompleteTestDelegate alloc] init];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  request.HTTPMethod = @"POST";

  NSBundle *bundle = [FPRTestUtils getBundle];
  NSURL *fileURL = [bundle URLForResource:@"smallDownloadFile" withExtension:@""];
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromFile:fileURL];
  [uploadTask resume];

  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  FPRNetworkTrace *networkTrace = [FPRNetworkTrace networkTraceFromObject:uploadTask];

  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.URLSessionTaskDidSendBodyDataTotalBytesSentTotalBytesExpectedCalled);
    XCTAssert(networkTrace.requestSize > 0);
    XCTAssert(
        [networkTrace
            timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                      andState:FPRNetworkTraceCheckpointStateRequestCompleted] > 0);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionTaskWillPerformHTTPRedirectionNewRequestCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionCompleteTestDelegate *delegate =
      [[FPRNSURLSessionCompleteTestDelegate alloc] init];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testRedirect"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  NSURLSessionTask *task = [session dataTaskWithRequest:request];
  [task resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:task]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(
        delegate.URLSessionTaskWillPerformHTTPRedirectionNewRequestCompletionHandlerCalled);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionDataTaskDidReceiveData {
  FPRNSURLSessionInstrument *instrument;
  NSURLSessionDataTask *dataTask;
  @autoreleasepool {
    instrument = [[FPRNSURLSessionInstrument alloc] init];
    [instrument registerInstrumentors];
    FPRNSURLSessionCompleteTestDelegate *delegate =
        [[FPRNSURLSessionCompleteTestDelegate alloc] init];
    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                          delegate:delegate
                                                     delegateQueue:nil];
    NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testBigDownload"];
    dataTask = [session dataTaskWithURL:URL];
    [dataTask resume];
    XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
    [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                         GCDWebServerResponse *_Nonnull response) {
      XCTAssertTrue(delegate.URLSessionDataTaskDidReceiveDataCalled);
      XCTAssertNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
    }];
  }
  [instrument deregisterInstrumentors];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionDownloadTaskDidFinishDownloadingToURL {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionCompleteTestDelegate *delegate =
      [[FPRNSURLSessionCompleteTestDelegate alloc] init];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:URL];
  [downloadTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.URLSessionDownloadTaskDidFinishDownloadingToURLCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionDownloadTaskDidResumeAtOffsetExpectedTotalBytes {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionTestDownloadDelegate *delegate =
      [[FPRNSURLSessionTestDownloadDelegate alloc] init];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testBigDownload"];
  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:URL];
  [downloadTask resume];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
  XCTAssertNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  XCTAssertTrue(delegate.URLSessionDownloadTaskDidResumeAtOffsetExpectedTotalBytesCalled);
  [instrument deregisterInstrumentors];
}

/** Tests that the called delegate selector is wrapped and calls through. */
- (void)testDelegateURLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesExpectedToWrite {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  FPRNSURLSessionCompleteTestDelegate *delegate =
      [[FPRNSURLSessionCompleteTestDelegate alloc] init];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testBigDownload"];
  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:URL];
  [downloadTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.URLSessionDownloadTaskDidWriteDataTotalBytesWrittenTotalBytesCalled);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests that even if a delegate doesn't implement a method, we add it to the delegate class. */
- (void)testDelegateUnimplementedURLSessionTaskDidCompleteWithError {
  FPRNSURLSessionTestDelegate *delegate = [[FPRNSURLSessionTestDelegate alloc] init];
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration defaultSessionConfiguration];
  XCTAssertFalse([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]);
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration
                                                        delegate:delegate
                                                   delegateQueue:nil];
  XCTAssertTrue([delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]);
  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:self.testServer.serverURL];
  [downloadTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  }];
  [instrument deregisterInstrumentors];
}

#pragma mark - Testing instance method wrapping

/** Tests that dataTaskWithRequest: returns a non-nil object. */
- (void)testDataTaskWithRequest {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"test"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
  XCTAssertNotNil(dataTask);
  [dataTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
  [instrument deregisterInstrumentors];
}

/** Tests that dataTaskWithRequest:completionHandler: returns a non-nil object. */
- (void)testDataTaskWithRequestAndCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"test"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];
  void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        [expectation fulfill];
      };
  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                              completionHandler:completionHandler];
  XCTAssertNotNil(dataTask);
  [dataTask resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Tests that dataTaskWithUrl:completionHandler: returns a non-nil object. */
- (void)testDataTaskWithUrlAndCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"test"];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];

  NSURLSessionDataTask *dataTask = nil;
  void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        XCTAssertNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
        [expectation fulfill];
      };
  dataTask = [session dataTaskWithURL:URL completionHandler:completionHandler];
  XCTAssertNotNil(dataTask);
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
  [dataTask resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Tests that uploadTaskWithRequest:fromFile: returns a non-nil object. */
- (void)testUploadTaskWithRequestFromFile {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];

  NSBundle *bundle = [FPRTestUtils getBundle];
  NSURL *fileURL = [bundle URLForResource:@"smallDownloadFile" withExtension:@""];
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromFile:fileURL];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  XCTAssertNotNil(uploadTask);
  [uploadTask resume];
  [instrument deregisterInstrumentors];
}

/** Tests that uploadTaskWithRequest:fromFile:completionHandler returns a non-nil object. */
- (void)testUploadTaskWithRequestFromFileCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];

  NSBundle *bundle = [FPRTestUtils getBundle];
  NSURL *fileURL = [bundle URLForResource:@"smallDownloadFile" withExtension:@""];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];
  void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        [expectation fulfill];
      };
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request
                                                             fromFile:fileURL
                                                    completionHandler:completionHandler];
  XCTAssertNotNil(uploadTask);
  [uploadTask resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Tests that uploadTaskWithRequest:fromData: returns a non-nil object. */
- (void)testUploadTaskWithRequestFromData {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  request.HTTPMethod = @"POST";
  NSData *data = [[NSData alloc] init];
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromData:data];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  XCTAssertNotNil(uploadTask);
  [uploadTask resume];
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertEqual(response.statusCode, 200);
    [instrument deregisterInstrumentors];
  }];
}

/** Tests that uploadTaskWithRequest:fromData:completionHandler: returns a non-nil object. */
- (void)testUploadTaskWithRequestFromDataCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];
  void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        [expectation fulfill];
      };
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request
                                                             fromData:[[NSData alloc] init]
                                                    completionHandler:completionHandler];
  XCTAssertNotNil(uploadTask);
  [uploadTask resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Tests that uploadTaskWithStreamedRequest: returns a non-nil object. */
- (void)testUploadTaskWithStreamedRequest {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithStreamedRequest:request];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  XCTAssertNotNil(uploadTask);
  [uploadTask resume];
  [instrument deregisterInstrumentors];
}

/** Tests that downloadTaskWithRequest: returns a non-nil object. */
- (void)testDownloadTaskWithRequest {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:request];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  XCTAssertNotNil(downloadTask);
  [downloadTask resume];
  [instrument deregisterInstrumentors];
}

/** Tests that downloadTaskWithRequest:completionHandler: returns a non-nil object. */
- (void)testDownloadTaskWithRequestCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];
  void (^completionHandler)(NSURL *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSURL *_Nullable location, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        [expectation fulfill];
      };
  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:request
                                                          completionHandler:completionHandler];
  XCTAssertNotNil(downloadTask);
  [downloadTask resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Tests that downloadTaskWithUrl:completionHandler: returns a non-nil object. */
- (void)testDownloadTaskWithURLCompletionHandler {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"test"];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler called"];

  NSURLSessionDownloadTask *downloadTask = nil;
  void (^completionHandler)(NSURL *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSURL *_Nullable location, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        XCTAssertNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
        [expectation fulfill];
      };
  downloadTask = [session downloadTaskWithURL:URL completionHandler:completionHandler];
  XCTAssertNotNil(downloadTask);
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  [downloadTask resume];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Validate that it works with NSMutableURLRequest URLs across data, upload, and download. */
- (void)testMutableRequestURLs {
  FPRNSURLSessionInstrument *instrument = [[FPRNSURLSessionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSMutableURLRequest *URLRequest = [NSMutableURLRequest requestWithURL:URL];
  NSURLSession *session = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];

  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:URLRequest];
  [dataTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:dataTask]);
  }];

  NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithRequest:URLRequest];
  [downloadTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:downloadTask]);
  }];

  URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  URLRequest.URL = URL;
  URLRequest.HTTPMethod = @"POST";
  NSData *uploadData = [[NSData alloc] init];
  NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:URLRequest
                                                             fromData:uploadData];
  [uploadTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  }];

  NSBundle *bundle = [FPRTestUtils getBundle];
  NSURL *fileURL = [bundle URLForResource:@"smallDownloadFile" withExtension:@""];
  uploadTask = [session uploadTaskWithRequest:URLRequest fromFile:fileURL];
  [uploadTask resume];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:uploadTask]);
  }];

  [instrument deregisterInstrumentors];
}

@end

#endif  // SWIFT_PACKAGE
