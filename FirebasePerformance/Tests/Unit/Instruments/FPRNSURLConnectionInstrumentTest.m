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

#if !SWIFT_PACKAGE

#import "FirebasePerformance/Tests/Unit/Instruments/FPRNSURLConnectionInstrumentTestDelegates.h"

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/Configurations/FPRConfigurations+Private.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNSURLConnectionInstrument.h"
#import "FirebasePerformance/Sources/Public/FirebasePerformance/FIRPerformance.h"

#import "FirebasePerformance/Tests/Unit/FPRTestCase.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"
#import "FirebasePerformance/Tests/Unit/Server/FPRHermeticTestServer.h"

@interface FPRNSURLConnectionInstrumentTest : FPRTestCase

/** Test server to create connections to. */
@property(nonatomic) FPRHermeticTestServer *testServer;

@end

@implementation FPRNSURLConnectionInstrumentTest

- (void)setUp {
  [super setUp];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:YES];
  self.testServer = [[FPRHermeticTestServer alloc] init];
  [self.testServer registerTestPaths];
  [self.testServer start];
}

- (void)tearDown {
  [super tearDown];
  FIRPerformance *performance = [FIRPerformance sharedInstance];
  [performance setDataCollectionEnabled:NO];
  [self.testServer stop];
  self.testServer = nil;
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

/** Tests calling +sendAsynchronousRequest:queue:completionHandler: is wrapped and calls
 *  through.
 */
- (void)testSendAsynchronousRequestQueueCompletionHandler {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  XCTestExpectation *expectation = [self expectationWithDescription:@"completionHandler was run"];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"test"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  [NSURLConnection
      sendAsynchronousRequest:request
                        queue:queue
            completionHandler:^(NSURLResponse *_Nullable response, NSData *_Nullable data,
                                NSError *_Nullable connectionError) {
              XCTAssertNil(connectionError);
              XCTAssertGreaterThan(data.length, 0);
              [expectation fulfill];
            }];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
  [instrument deregisterInstrumentors];
}

/** Tests calling +sendAsynchronousRequest:queue:completionHandler: is wrapped and calls
 *  through, even with a nil completionHandler.
 */
- (void)testSendAsynchronousRequestQueueWithNilCompletionHandler {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"test"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:nil];
#pragma clang diagnostic pop

  // Wait for a moment to ensure that the request has gone through.
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertEqualObjects(request.URL.absoluteString, URL.absoluteString);
    XCTAssertEqual(response.statusCode, 200);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -initWithRequest:delegate: is wrapped and calls through. */
- (void)testInitWithRequestDelegate {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  [self.testServer stop];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  XCTAssertNotNil(connection);
  [connection start];
  // Only let it check for a connection for a half second.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  XCTAssertTrue(delegate.connectionDidFailWithErrorCalled);
  [self.testServer start];
  [instrument deregisterInstrumentors];
}

/** Tests calling -initWithRequest:delegate: is wrapped and calls through for NSOperation based
 *  requests.
 */
- (void)testInitWithOperationRequestDelegate {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  [self.testServer stop];
  FPRNSURLConnectionOperationTestDelegate *delegate =
      [[FPRNSURLConnectionOperationTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  XCTAssertNotNil(connection);
  [connection start];
  // Only let it check for a connection for a half second.
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  XCTAssertTrue(delegate.connectionDidFailWithErrorCalled);
  [self.testServer start];
  [instrument deregisterInstrumentors];
}

/** Tests calling -initWithRequest:delegate: is wrapped and calls through with nil delegate. */
- (void)testInitWithRequestAndNilDelegate {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.testServer.serverURL];
  [request setTimeoutInterval:10.0];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                delegate:nil
                                                        startImmediately:NO];
  XCTAssertNotNil(connection);
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -initWithRequest:delegate:startImmediately: doesn't install a delegate. */
- (void)testInitWithRequestDelegateStartImmediately {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  [self.testServer stop];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request
                                                                delegate:delegate
                                                        startImmediately:NO];
  XCTAssertNotNil(connection);
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  XCTAssertTrue(delegate.connectionDidFailWithErrorCalled);
  XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self.testServer start];
  [instrument deregisterInstrumentors];
}

/** Tests calling +connectionWithRequest:delegate: calls already wrapped methods. */
- (void)testConnectionWithRequestDelegate {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -start is wrapped and calls through. */
- (void)testStart {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  XCTAssertNotNil(connection);
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -start through startImmediately: is wrapped and calls through. */
- (void)testStartThroughStartImmediately {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  XCTAssertNotNil(connection);
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [connection start];
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -cancel is wrapped and calls through. */
- (void)testCancel {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  XCTAssertNotNil(connection);
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [connection start];
  [connection cancel];
  XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [instrument deregisterInstrumentors];
}

#pragma mark - Delegate methods

/** Tests calling -connection:didFailWithError: is wrapped and calls through. */
- (void)testConnectionDidFailWithError {
  self.appFake.fakeIsDataCollectionDefaultEnabled = YES;
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://nonurl/"]];
  [self.testServer stop];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
  XCTAssertTrue(delegate.connectionDidFailWithErrorCalled);
  XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self.testServer start];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connection:willSendRequest:redirectResponse: is wrapped and calls through.*/
- (void)testConnectionWillSendRequestRedirectResponse {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testRedirect"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionWillSendRequestRedirectResponseCalled);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connection:didReceiveResponse: is wrapped and calls through. */
- (void)testConnectionDidReceiveResponse {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidReceiveResponseCalled);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connection:didReceiveData: is wrapped and calls through. */
- (void)testConnectionDidReceiveData {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testBigDownload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  FPRNSURLConnectionDidReceiveDataDelegate *delegate =
      [[FPRNSURLConnectionDidReceiveDataDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidReceiveDataCalled);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite: is
 *  wrapped and calls through.
 */
- (void)testConnectionDidSendBodyDataTotalBytesWrittenTotalBytesExpectedToWrite {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  request.HTTPMethod = @"POST";

  NSBundle *bundle = [FPRTestUtils getBundle];
  NSURL *fileURL = [bundle URLForResource:@"smallDownloadFile" withExtension:@""];
  request.HTTPBody = [NSData dataWithContentsOfURL:fileURL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  FPRNetworkTrace *networkTrace = [FPRNetworkTrace networkTraceFromObject:connection];

  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(
        delegate.connectionDidSendBodyDataTotalBytesWrittenTotalBytesExpectedToWriteCalled);
    XCTAssert(networkTrace.requestSize > 0);
    XCTAssert(
        [networkTrace
            timeIntervalBetweenCheckpointState:FPRNetworkTraceCheckpointStateInitiated
                                      andState:FPRNetworkTraceCheckpointStateRequestCompleted] > 0);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connectionDidFinishLoading: is wrapped and calls through. */
- (void)testConnectionDidFinishLoading {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  FPRNSURLConnectionDidReceiveDataDelegate *delegate =
      [[FPRNSURLConnectionDidReceiveDataDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidFinishLoadingCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connection:didWriteData:totalBytesWritten:expectedTotalBytes is wrapped and
 *  calls through.
 */
- (void)testConnectionDidWriteDataTotalBytesWrittenExpectedTotalBytes {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testUpload"];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  request.HTTPMethod = @"POST";
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidWriteDataTotalBytesWrittenExpectedTotalBytesCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests calling -connectionDidFinishDownloading:destinationURL: is wrapped and calls through.
 */
- (void)testConnectionDidFinishDownloadingDestinationURL {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  dispatch_queue_t queue = dispatch_queue_create([NSStringFromSelector(_cmd) UTF8String], 0);
  dispatch_async(queue, ^{

                 });
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidFinishDownloadingDestinationURLCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests NSURLDownloadDelegate completion methods gets called even after SDK swizzles that
 *  APIs.
 */
- (void)testDownloadDelegateCompletionAPIGetsCalled {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURLRequest *request = [NSURLRequest requestWithURL:self.testServer.serverURL];
  FPRNSURLConnectionDownloadTestDelegate *delegate =
      [[FPRNSURLConnectionDownloadTestDelegate alloc] init];
  XCTAssertFalse([delegate respondsToSelector:@selector(connectionDidFinishLoading:)]);
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidFinishDownloadingDestinationURLCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests NSURLDataDelegate completion handler gets called even after SDK swizzles that APIs.
 */
- (void)testDataDelegateCompletionAPIGetsCalled {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  FPRNSURLConnectionDataTestDelegate *delegate = [[FPRNSURLConnectionDataTestDelegate alloc] init];
  SEL selector = @selector(connectionDidFinishDownloading:destinationURL:);
  XCTAssertFalse([delegate respondsToSelector:selector]);
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidFinishLoadingCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

/** Tests NSURLDownloadDelegate completion methods gets called even if NSURLDataDelegate is
 *  implemented.
 */
- (void)testDownloadDelegateCompletionAPIGetsCalledEvenIfDataDelegateIsImplemented {
  FPRNSURLConnectionInstrument *instrument = [[FPRNSURLConnectionInstrument alloc] init];
  [instrument registerInstrumentors];
  NSURL *URL = [self.testServer.serverURL URLByAppendingPathComponent:@"testDownload"];
  NSURLRequest *request = [NSURLRequest requestWithURL:URL];
  FPRNSURLConnectionCompleteTestDelegate *delegate =
      [[FPRNSURLConnectionCompleteTestDelegate alloc] init];
  SEL selector = @selector(connectionDidFinishDownloading:destinationURL:);
  XCTAssertTrue([delegate respondsToSelector:selector]);
  XCTAssertTrue([delegate respondsToSelector:@selector(connectionDidFinishLoading:)]);
  NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:delegate];
  [connection start];
  XCTAssertNotNil([FPRNetworkTrace networkTraceFromObject:connection]);
  [self waitAndRunBlockAfterResponse:^(id self, GCDWebServerRequest *_Nonnull request,
                                       GCDWebServerResponse *_Nonnull response) {
    XCTAssertTrue(delegate.connectionDidFinishDownloadingDestinationURLCalled);
    XCTAssertFalse(delegate.connectionDidFinishLoadingCalled);
    XCTAssertNil([FPRNetworkTrace networkTraceFromObject:connection]);
  }];
  [instrument deregisterInstrumentors];
}

@end

#endif  // SWIFT_PACKAGE
