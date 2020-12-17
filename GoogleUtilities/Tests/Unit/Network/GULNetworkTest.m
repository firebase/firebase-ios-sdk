// Copyright 2018 Google
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

#import "GoogleUtilities/Tests/Unit/Network/third_party/GTMHTTPServer.h"

#import <XCTest/XCTest.h>
#import "OCMock.h"

#if !TARGET_OS_MACCATALYST
// These tests are flaky on Catalyst. One of the tests typically fails.

#import "GoogleUtilities/NSData+zlib/Public/GoogleUtilities/GULNSData+zlib.h"
#import "GoogleUtilities/Network/Public/GoogleUtilities/GULNetwork.h"
#import "GoogleUtilities/Reachability/Public/GoogleUtilities/GULReachabilityChecker.h"

@interface GULNetwork ()

- (void)reachability:(GULReachabilityChecker *)reachability
       statusChanged:(GULReachabilityStatus)status;

@end

@interface GULNetworkURLSession ()

- (void)maybeRemoveTempFilesAtURL:(NSURL *)tempFile expiringTime:(NSTimeInterval)expiringTime;

@end

@interface GULNetworkTest : XCTestCase <GULNetworkReachabilityDelegate>
@end

@implementation GULNetworkTest {
  dispatch_queue_t _backgroundQueue;
  GULNetwork *_network;

  /// Fake Server.
  GTMHTTPServer *_httpServer;
  GTMHTTPRequestMessage *_request;
  int _statusCode;

  // For network reachability test.
  BOOL _fakeNetworkIsReachable;
  BOOL _currentNetworkStatus;
  GULReachabilityStatus _fakeReachabilityStatus;
}

#pragma mark - Setup and teardown

- (void)setUp {
  [super setUp];

  _fakeNetworkIsReachable = YES;
  _statusCode = 200;
  _request = nil;

  _httpServer = [[GTMHTTPServer alloc] initWithDelegate:self];

  // Start the server.
  NSError *error = nil;
  XCTAssertTrue([_httpServer start:&error], @"Failed to start HTTP server: %@", error);

  _network = [[GULNetwork alloc] init];
  _backgroundQueue = dispatch_queue_create("Test queue", DISPATCH_QUEUE_SERIAL);

  _request = nil;
}

- (void)tearDown {
  _network = nil;
  _backgroundQueue = nil;
  _request = nil;

  [_httpServer stop];
  _httpServer = nil;

  [super tearDown];
}

#pragma mark - Test reachability

- (void)testReachability {
  _network.reachabilityDelegate = self;

  id reachability = [_network valueForKey:@"_reachability"];
  XCTAssertNotNil(reachability);

  id reachabilityMock = OCMPartialMock(reachability);
  [[[reachabilityMock stub] andCall:@selector(reachabilityStatus)
                           onObject:self] reachabilityStatus];

  // Fake scenario with connectivity.
  _fakeNetworkIsReachable = YES;
  _fakeReachabilityStatus = kGULReachabilityViaWifi;
  [_network reachability:reachabilityMock statusChanged:[reachabilityMock reachabilityStatus]];
  XCTAssertTrue([_network isNetworkConnected]);
  XCTAssertEqual(_currentNetworkStatus, _fakeNetworkIsReachable);

  // Fake scenario without connectivity.
  _fakeNetworkIsReachable = NO;
  _fakeReachabilityStatus = kGULReachabilityNotReachable;
  [_network reachability:reachabilityMock statusChanged:[reachabilityMock reachabilityStatus]];
  XCTAssertFalse([_network isNetworkConnected]);
  XCTAssertEqual(_currentNetworkStatus, _fakeNetworkIsReachable);

  [reachabilityMock stopMocking];
  reachabilityMock = nil;
}

#pragma mark - Test POST Foreground

- (void)testSessionNetwork_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/2", _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             [self verifyResponse:response error:error];
             [self verifyRequest];
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testSessionNetworkShouldReturnError_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/3", _httpServer.port]];
  _statusCode = 500;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 500);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilURLNSURLSession_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  _statusCode = 200;

  [_network postURL:nil
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testEmptyURLNSURLSession_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  _statusCode = 200;

  [_network postURL:[NSURL URLWithString:@""]
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testEmptyPayloadNSURLSession_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSData *uncompressedData = [[NSData alloc] init];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/2", _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNil(error);
             XCTAssertNotNil(self->_request);
             XCTAssertEqualObjects([self->_request.URL absoluteString], [url absoluteString]);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilQueueNSURLSession_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/1", _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:nil
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             [self verifyResponse:response error:error];
             [self verifyRequest];
             [expectation fulfill];
           }];

  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testHasRequestPendingNSURLSession_POST_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/hasRequestPending",
                                                      _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             [self verifyResponse:response error:error];
             [self verifyRequest];

             XCTAssertFalse(self->_network.hasUploadInProgress,
                            @"hasUploadInProgress must be false");
             [expectation fulfill];
           }];

  XCTAssertTrue(self->_network.hasUploadInProgress, @"hasUploadInProgress must be true");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

#pragma mark - Test POST Background

- (void)testSessionNetwork_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/2", _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             [self verifyResponse:response error:error];
             [self verifyRequest];
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testSessionNetworkShouldReturnError_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/3", _httpServer.port]];
  _statusCode = 500;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 500);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilURLNSURLSession_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  _statusCode = 200;

  [_network postURL:nil
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testEmptyURLNSURLSession_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  _statusCode = 200;

  [_network postURL:[NSURL URLWithString:@""]
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testEmptyPayloadNSURLSession_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSData *uncompressedData = [[NSData alloc] init];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/2", _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNil(error);
             XCTAssertNotNil(self->_request);
             XCTAssertEqualObjects([self->_request.URL absoluteString], [url absoluteString]);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilQueueNSURLSession_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/1", _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:nil
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             [self verifyResponse:response error:error];
             [self verifyRequest];
             [expectation fulfill];
           }];

  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testHasRequestPendingNSURLSession_POST_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSData *uncompressedData = [@"Google" dataUsingEncoding:NSUTF8StringEncoding];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/hasRequestPending",
                                                      _httpServer.port]];
  _statusCode = 200;

  [_network postURL:url
                     payload:uncompressedData
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             [self verifyResponse:response error:error];
             [self verifyRequest];

             XCTAssertFalse(self->_network.hasUploadInProgress,
                            @"hasUploadInProgress must be false");
             [expectation fulfill];
           }];

  XCTAssertTrue(self->_network.hasUploadInProgress, @"hasUploadInProgress must be true");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

#pragma mark - GET Methods Foreground

- (void)testSessionNetworkAsync_GET_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/2", _httpServer.port]];
  _statusCode = 200;

  [_network getURL:url
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testSessionNetworkShouldReturnError_GET_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/3", _httpServer.port]];
  _statusCode = 500;

  [_network getURL:url
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 500);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilURLNSURLSession_GET_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  _statusCode = 200;

  [_network getURL:nil
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testEmptyURLNSURLSession_GET_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  _statusCode = 200;

  [_network getURL:[NSURL URLWithString:@""]
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilQueueNSURLSession_GET_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/1", _httpServer.port]];
  _statusCode = 200;

  [_network getURL:url
                     headers:nil
                       queue:nil
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testHasRequestPendingNSURLSession_GET_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/hasRequestPending",
                                                      _httpServer.port]];
  _statusCode = 200;

  [_network getURL:url
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);
             XCTAssertFalse(self->_network.hasUploadInProgress,
                            @"hasUploadInProgress must be false");
             [expectation fulfill];
           }];

  XCTAssertTrue(self->_network.hasUploadInProgress, @"hasUploadInProgress must be true");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testHeaders_foreground {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/3", _httpServer.port]];
  _statusCode = 200;

  NSDictionary *headers = @{@"Version" : @"123"};

  [_network getURL:url
                     headers:headers
                       queue:_backgroundQueue
      usingBackgroundSession:NO
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);

             NSString *version = [self->_request.allHeaderFieldValues valueForKey:@"Version"];
             XCTAssertEqualObjects(version, @"123");

             [expectation fulfill];
           }];

  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

#pragma mark - GET Methods Background

- (void)testSessionNetworkAsync_GET_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/2", _httpServer.port]];
  _statusCode = 200;

  [_network getURL:url
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testSessionNetworkShouldReturnError_GET_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/3", _httpServer.port]];
  _statusCode = 500;

  [_network getURL:url
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(((NSHTTPURLResponse *)response).statusCode, 500);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilURLNSURLSession_GET_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  _statusCode = 200;

  [_network getURL:nil
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testEmptyURLNSURLSession_GET_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  _statusCode = 200;

  [_network getURL:[NSURL URLWithString:@""]
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertEqual(error.code, GULErrorCodeNetworkInvalidURL);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testNilQueueNSURLSession_GET_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/1", _httpServer.port]];
  _statusCode = 200;

  [_network getURL:url
                     headers:nil
                       queue:nil
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);
             XCTAssertFalse(self->_network.hasUploadInProgress, "There must be no pending request");
             [expectation fulfill];
           }];
  XCTAssertTrue(self->_network.hasUploadInProgress, "There must be a pending request");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testHasRequestPendingNSURLSession_GET_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];
  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/hasRequestPending",
                                                      _httpServer.port]];
  _statusCode = 200;

  [_network getURL:url
                     headers:nil
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);
             XCTAssertFalse(self->_network.hasUploadInProgress,
                            @"hasUploadInProgress must be false");
             [expectation fulfill];
           }];

  XCTAssertTrue(self->_network.hasUploadInProgress, @"hasUploadInProgress must be true");
  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

- (void)testHeaders_background {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block is called"];

  NSURL *url =
      [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/3", _httpServer.port]];
  _statusCode = 200;

  NSDictionary *headers = @{@"Version" : @"123"};

  [_network getURL:url
                     headers:headers
                       queue:_backgroundQueue
      usingBackgroundSession:YES
           completionHandler:^(NSHTTPURLResponse *response, NSData *data, NSError *error) {
             XCTAssertNotNil(data);
             NSString *responseBody = [[NSString alloc] initWithData:data
                                                            encoding:NSUTF8StringEncoding];
             XCTAssertEqualObjects(responseBody, @"<html><body>Hello, World!</body></html>");
             XCTAssertNil(error);

             NSString *version = [self->_request.allHeaderFieldValues valueForKey:@"Version"];
             XCTAssertEqualObjects(version, @"123");

             [expectation fulfill];
           }];

  // Wait a little bit so the server has enough time to respond.
  [self waitForExpectationsWithTimeout:10
                               handler:^(NSError *error) {
                                 if (error) {
                                   XCTFail(@"Timeout Error: %@", error);
                                 }
                               }];
}

#pragma mark - Test clean up files

- (void)testRemoveExpiredFiles {
  NSError *writeError = nil;
  NSFileManager *fileManager = [NSFileManager defaultManager];

  GULNetworkURLSession *session = [[GULNetworkURLSession alloc]
      initWithNetworkLoggerDelegate:(id<GULNetworkLoggerDelegate>)_network];
#if TARGET_OS_TV
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
  NSArray *paths =
      NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
#endif
  NSString *applicationSupportDirectory = paths.firstObject;
  NSArray *tempPathComponents = @[
    applicationSupportDirectory, kGULNetworkApplicationSupportSubdirectory,
    @"GULNetworkTemporaryDirectory"
  ];
  NSURL *folderURL = [NSURL fileURLWithPathComponents:tempPathComponents];
  [fileManager createDirectoryAtURL:folderURL
        withIntermediateDirectories:YES
                         attributes:nil
                              error:&writeError];

  NSURL *tempFile1 = [folderURL URLByAppendingPathComponent:@"FIRUpload_temp_123"];
  [self createTempFileAtURL:tempFile1];
  NSURL *tempFile2 = [folderURL URLByAppendingPathComponent:@"FIRUpload_temp_456"];
  [self createTempFileAtURL:tempFile2];

  XCTAssertTrue([fileManager fileExistsAtPath:tempFile1.path]);
  XCTAssertTrue([fileManager fileExistsAtPath:tempFile2.path]);

  NSDate *now =
      [[NSDate date] dateByAddingTimeInterval:1];  // Start mocking the clock to avoid flakiness.
  id mockDate = OCMStrictClassMock([NSDate class]);
  [[[mockDate stub] andReturn:now] date];

  // The file should not be removed since it is not expired yet.
  [session maybeRemoveTempFilesAtURL:folderURL expiringTime:20];
  XCTAssertTrue([fileManager fileExistsAtPath:tempFile1.path]);
  XCTAssertTrue([fileManager fileExistsAtPath:tempFile2.path]);

  [mockDate stopMocking];
  mockDate = nil;

  now = [[NSDate date] dateByAddingTimeInterval:100];  // Move forward in time 100s.
  mockDate = OCMStrictClassMock([NSDate class]);
  [[[mockDate stub] andReturn:now] date];

  [session maybeRemoveTempFilesAtURL:folderURL expiringTime:20];
  XCTAssertFalse([fileManager fileExistsAtPath:tempFile1.path]);
  XCTAssertFalse([fileManager fileExistsAtPath:tempFile2.path]);
  [mockDate stopMocking];
  mockDate = nil;
}

#pragma mark - Internal Methods

- (void)createTempFileAtURL:(NSURL *)fileURL {
  // Create a dictionary and write it to file.
  NSDictionary *someContent = @{@"object" : @"key"};
  [someContent writeToURL:fileURL atomically:YES];
}

- (void)verifyResponse:(NSHTTPURLResponse *)response error:(NSError *)error {
  XCTAssertNil(error, @"Error is not expected");
  XCTAssertNotNil(response, @"Error is not expected");
}

- (void)verifyRequest {
  XCTAssertNotNil(_request, @"Request cannot be nil");

  // Test whether the request is compressed correctly.
  NSData *requestBody = [_request body];
  NSData *decompressedRequestData = [NSData gul_dataByInflatingGzippedData:requestBody error:NULL];
  NSString *requestString = [[NSString alloc] initWithData:decompressedRequestData
                                                  encoding:NSUTF8StringEncoding];
  XCTAssertEqualObjects(requestString, @"Google", @"Request is not compressed correctly.");

  // The request has to be a POST.
  XCTAssertEqualObjects([_request method], @"POST", @"Request method has to be POST");

  // Content length has to be set correctly.
  NSString *contentLength = [_request.allHeaderFieldValues valueForKey:@"Content-Length"];
  XCTAssertEqualObjects(contentLength, @"26", @"Content Length is incorrect");

  NSString *contentEncoding = [_request.allHeaderFieldValues valueForKey:@"Content-Encoding"];
  XCTAssertEqualObjects(contentEncoding, @"gzip", @"Content Encoding is incorrect");
}

#pragma mark - Helper Methods

- (GTMHTTPResponseMessage *)httpServer:(GTMHTTPServer *)server
                         handleRequest:(GTMHTTPRequestMessage *)request {
  _request = request;

  NSData *html =
      [@"<html><body>Hello, World!</body></html>" dataUsingEncoding:NSUTF8StringEncoding];
  return [GTMHTTPResponseMessage responseWithBody:html
                                      contentType:@"text/html; charset=UTF-8"
                                       statusCode:_statusCode];
}

- (BOOL)isReachable {
  return _fakeNetworkIsReachable;
}

- (GULReachabilityStatus)reachabilityStatus {
  return _fakeReachabilityStatus;
}

#pragma mark - FIRReachabilityDelegate

- (void)reachabilityDidChange {
  _currentNetworkStatus = _fakeNetworkIsReachable;
}

@end

#endif  // TARGET_OS_MACCATALYST
