/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import "FIRIAMMessageContentDataWithImageURL.h"

static NSString *defaultTitle = @"Message Title";
static NSString *defaultBody = @"Message Body";
static NSString *defaultActionButtonText = @"Take action";
static NSString *defaultActionURL = @"https://foo.com/bar";
static NSString *defaultImageURL = @"http://firebase.com/iam/test.png";

@interface FIRIAMMessageContentDataWithImageURLTests : XCTestCase
@property NSURLSession *mockedNSURLSession;

@property FIRIAMMessageContentDataWithImageURL *defaultContentDataWithImageURL;
@end

@implementation FIRIAMMessageContentDataWithImageURLTests

- (void)setUp {
  [super setUp];

  _mockedNSURLSession = OCMClassMock([NSURLSession class]);
  _defaultContentDataWithImageURL = [[FIRIAMMessageContentDataWithImageURL alloc]
      initWithMessageTitle:defaultTitle
               messageBody:defaultBody
          actionButtonText:defaultActionButtonText
                 actionURL:[NSURL URLWithString:defaultActionURL]
                  imageURL:[NSURL URLWithString:defaultImageURL]
           usingURLSession:_mockedNSURLSession];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testReadingTitleAndBodyBackCorrectly {
  XCTAssertEqualObjects(defaultTitle, self.defaultContentDataWithImageURL.titleText);
  XCTAssertEqualObjects(defaultBody, self.defaultContentDataWithImageURL.bodyText);
}

- (void)testReadingActionButtonTextCorrectly {
  XCTAssertEqualObjects(defaultActionButtonText,
                        self.defaultContentDataWithImageURL.actionButtonText);
}

- (void)testURLRequestUsingCorrectImageURL {
  __block NSURLRequest *capturedNSURLRequest;
  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
        capturedNSURLRequest = request;
        return YES;
      }]
        completionHandler:[OCMArg any]  // second parameter is the callback which we don't care in
                                        // this unit testing
  ]);

  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSError *_Nullable error){
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  XCTAssertEqualObjects([capturedNSURLRequest URL].absoluteString, defaultImageURL);
}

- (void)testReportErrorOnNonSuccessHTTPStatusCode {
  // NSURLSessionDataTask * mockedDataTask = OCMClassMock([NSURLSessionDataTask class]);
  __block void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(id completionHandler) {
          capturedCompletionHandler = completionHandler;
          return YES;
        }]  // second parameter is the callback which we don't care in this unit testing
  ]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
        XCTAssertNil(imageData);
        XCTAssertNotNil(error);  // we should report error due to the unsuccessful http status code
        [expectation fulfill];
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  // by this time we should have capturedCompletionHandler being the callback block for the
  // NSURLSessionDataTask, now supply it with invalid http status code to see how the block from
  // loadImageDataWithBlock: would react to it.

  NSURL *url = [[NSURL alloc] initWithString:defaultImageURL];

  NSHTTPURLResponse *unsuccessfulHTTPResponse = [[NSHTTPURLResponse alloc] initWithURL:url
                                                                            statusCode:404
                                                                           HTTPVersion:nil
                                                                          headerFields:nil];
  capturedCompletionHandler(nil, unsuccessfulHTTPResponse, nil);

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testReportErrorOnGeneralNSErrorFromNSURLSession {
  NSError *customError = [[NSError alloc] initWithDomain:@"Error Domain" code:100 userInfo:nil];
  __block void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(id completionHandler) {
          capturedCompletionHandler = completionHandler;
          return YES;
        }]  // second parameter is the callback which we don't care in this unit testing
  ]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
        XCTAssertNil(imageData);
        XCTAssertNotNil(error);  // we should report error due to the unsuccessful http status code
        XCTAssertEqualObjects(error, customError);
        [expectation fulfill];
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  // by this time we should have capturedCompletionHandler being the callback block for the
  // NSURLSessionDataTask, now feed it with an NSError see how the block from
  // loadImageDataWithBlock: would react to it.
  capturedCompletionHandler(nil, nil, customError);

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testReportErrorOnNonImageContentTypeResponse {
  __block void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(id completionHandler) {
          capturedCompletionHandler = completionHandler;
          return YES;
        }]  // second parameter is the callback which we don't care in this unit testing
  ]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
        XCTAssertNil(imageData);
        XCTAssertNotNil(error);  // we should report error due to the http response
                                 // content type being invalid
        [expectation fulfill];
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  // by this time we should have capturedCompletionHandler being the callback block for the
  // NSURLSessionDataTask, now feed it with a non-image http response to see how the block from
  // loadImageDataWithBlock: would react to it.

  NSURL *url = [[NSURL alloc] initWithString:defaultImageURL];
  NSHTTPURLResponse *nonImageContentTypeHTTPResponse =
      [[NSHTTPURLResponse alloc] initWithURL:url
                                  statusCode:200
                                 HTTPVersion:nil
                                headerFields:@{@"Content-Type" : @"non-image/jpeg"}];
  capturedCompletionHandler(nil, nonImageContentTypeHTTPResponse, nil);

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testGettingImageDataSuccessfully {
  NSString *imageDataString = @"test image data";
  NSData *imageData = [imageDataString dataUsingEncoding:NSUTF8StringEncoding];

  __block void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(id completionHandler) {
          capturedCompletionHandler = completionHandler;
          return YES;
        }]  // second parameter is the callback which we don't care in this unit testing
  ]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSError *_Nullable error) {
        XCTAssertNil(error);  // no error is reported
        NSString *fetchedImageDataString = [[NSString alloc] initWithData:imageData
                                                                 encoding:NSUTF8StringEncoding];

        XCTAssertEqualObjects(imageDataString, fetchedImageDataString);

        [expectation fulfill];
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  NSURL *url = [[NSURL alloc] initWithString:defaultImageURL];
  NSHTTPURLResponse *successfulHTTPResponse =
      [[NSHTTPURLResponse alloc] initWithURL:url
                                  statusCode:200
                                 HTTPVersion:nil
                                headerFields:@{@"Content-Type" : @"image/jpeg"}];
  // by this time we should have capturedCompletionHandler being the callback block for the
  // NSURLSessionDataTask, now feed it with image data to see how the block from
  // loadImageDataWithBlock: would react to it.
  capturedCompletionHandler(imageData, successfulHTTPResponse, nil);
  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}
@end
