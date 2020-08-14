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
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentDataWithImageURL.h"

static NSString *defaultTitle = @"Message Title";
static NSString *defaultBody = @"Message Body";
static NSString *defaultActionButtonText = @"Take action";
static NSString *defaultSecondaryActionButtonText = @"Dismiss";
static NSString *defaultActionURL = @"https://foo.com/bar";
static NSString *defaultSecondaryActionURL = @"https://foo.com/baz";
static NSString *defaultImageURL = @"http://firebase.com/iam/test.png";
static NSString *defaultLandscapeImageURL = @"http://firebase.com/iam/test-landscape.png";

@interface FIRIAMMessageContentDataWithImageURLTests : XCTestCase
@property NSURLSession *mockedNSURLSession;

@property FIRIAMMessageContentDataWithImageURL *defaultContentDataWithImageURL;
@property FIRIAMMessageContentDataWithImageURL *defaultContentDataWithBothImageURLs;
@end

typedef void (^ImageFetchExpectationsBlock)(NSData *, NSData *, NSError *);

@implementation FIRIAMMessageContentDataWithImageURLTests

- (void)setUp {
  [super setUp];

  _mockedNSURLSession = OCMClassMock([NSURLSession class]);
  _defaultContentDataWithImageURL = [[FIRIAMMessageContentDataWithImageURL alloc]
           initWithMessageTitle:defaultTitle
                    messageBody:defaultBody
               actionButtonText:defaultActionButtonText
      secondaryActionButtonText:defaultSecondaryActionButtonText
                      actionURL:[NSURL URLWithString:defaultActionURL]
             secondaryActionURL:[NSURL URLWithString:defaultSecondaryActionURL]
                       imageURL:[NSURL URLWithString:defaultImageURL]
              landscapeImageURL:[NSURL URLWithString:defaultLandscapeImageURL]
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

- (void)testURLRequestUsingCorrectImageURLWithOnlyPortrait {
  __block NSURLRequest *capturedNSURLRequest;
  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
        capturedNSURLRequest = request;
        return YES;
      }]
        completionHandler:[OCMArg any]  // second parameter is the callback which we don't care in
                                        // this unit testing
  ]);

  FIRIAMMessageContentDataWithImageURL *portraitOnlyContentData =
      [[FIRIAMMessageContentDataWithImageURL alloc]
               initWithMessageTitle:defaultTitle
                        messageBody:defaultBody
                   actionButtonText:defaultActionButtonText
          secondaryActionButtonText:defaultSecondaryActionButtonText
                          actionURL:[NSURL URLWithString:defaultActionURL]
                 secondaryActionURL:[NSURL URLWithString:defaultSecondaryActionURL]
                           imageURL:[NSURL URLWithString:defaultImageURL]
                  landscapeImageURL:nil
                    usingURLSession:_mockedNSURLSession];

  [portraitOnlyContentData
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                               NSError *error){
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  XCTAssertEqualObjects([capturedNSURLRequest URL].absoluteString, defaultImageURL);
}

- (void)testURLRequestUsingCorrectImageURLs {
  __block NSURLRequest *capturedNSURLRequestForPortraitImage;
  __block NSURLRequest *capturedNSURLRequestForLandscapeImage;
  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
        if ([request.URL.absoluteString isEqualToString:defaultImageURL]) {
          capturedNSURLRequestForPortraitImage = request;
        } else if ([request.URL.absoluteString isEqualToString:defaultLandscapeImageURL]) {
          capturedNSURLRequestForLandscapeImage = request;
        }
        return YES;
      }]
        completionHandler:[OCMArg any]  // second parameter is the callback which we don't care in
                                        // this unit testing
  ]);

  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                               NSError *error){
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  XCTAssertNotNil(capturedNSURLRequestForPortraitImage);
  XCTAssertNotNil(capturedNSURLRequestForLandscapeImage);
}

- (void)testReportErrorOnNonSuccessHTTPStatusCode {
  // Used to capture both portrait and landscape callbacks.
  NSMutableArray *completionHandlers = [NSMutableArray array];

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(void (^capturedCompletionHandler)(
                              NSData *data, NSURLResponse *response, NSError *error)) {
          [completionHandlers addObject:capturedCompletionHandler];
          return YES;
        }]]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                               NSError *error) {
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

  for (void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error)
           in completionHandlers) {
    capturedCompletionHandler(nil, unsuccessfulHTTPResponse, nil);
  }

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testReportErrorOnGeneralNSErrorFromNSURLSession {
  NSError *customError = [[NSError alloc] initWithDomain:@"Error Domain" code:100 userInfo:nil];

  // Used to capture both portrait and landscape callbacks.
  NSMutableArray *completionHandlers = [NSMutableArray array];

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(void (^capturedCompletionHandler)(
                              NSData *data, NSURLResponse *response, NSError *error)) {
          [completionHandlers addObject:capturedCompletionHandler];
          return YES;
        }]]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                               NSError *error) {
        XCTAssertNil(imageData);
        XCTAssertNotNil(error);  // we should report error due to the unsuccessful http status code
        XCTAssertEqualObjects(error, customError);
        [expectation fulfill];
      }];

  // verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  for (void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error)
           in completionHandlers) {
    capturedCompletionHandler(nil, nil, customError);
  }

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testReportErrorOnNonImageContentTypeResponse {
  // Used to capture both portrait and landscape callbacks.
  NSMutableArray *completionHandlers = [NSMutableArray array];

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(void (^capturedCompletionHandler)(
                              NSData *data, NSURLResponse *response, NSError *error)) {
          [completionHandlers addObject:capturedCompletionHandler];
          return YES;
        }]]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                               NSError *error) {
        XCTAssertNil(imageData);
        // We should report error due to the HTTP response content type being invalid.
        XCTAssertNotNil(error);
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

  for (void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error)
           in completionHandlers) {
    capturedCompletionHandler(nil, nonImageContentTypeHTTPResponse, nil);
  }

  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testGettingBothImagesSuccessfully {
  NSData *portraitImageData = [@"test portrait image data" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *landscapeImageData =
      [@"test landscape image data" dataUsingEncoding:NSUTF8StringEncoding];

  // Used to capture both portrait and landscape callbacks.
  NSMutableArray *completionHandlers = [NSMutableArray array];

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(void (^capturedCompletionHandler)(
                              NSData *data, NSURLResponse *response, NSError *error)) {
          [completionHandlers addObject:capturedCompletionHandler];
          return YES;
        }]]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL loadImageDataWithBlock:^(NSData *_Nullable imageData,
                                                            NSData *_Nullable landscapeImageData,
                                                            NSError *error) {
    XCTAssertNil(error);  // no error is reported
    NSString *fetchedPortraitImageDataString = [[NSString alloc] initWithData:imageData
                                                                     encoding:NSUTF8StringEncoding];
    NSString *fetchedLandscapeImageDataString =
        [[NSString alloc] initWithData:landscapeImageData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(@"test portrait image data", fetchedPortraitImageDataString);
    XCTAssertEqualObjects(@"test landscape image data", fetchedLandscapeImageDataString);

    [expectation fulfill];
  }];

  // Verify that the dataTaskWithRequest:completionHandler: is triggered for NSURLSession object.
  OCMVerify([self.mockedNSURLSession dataTaskWithRequest:[OCMArg any]
                                       completionHandler:[OCMArg any]]);

  NSURL *url = [[NSURL alloc] initWithString:defaultImageURL];
  NSHTTPURLResponse *successfulHTTPResponse =
      [[NSHTTPURLResponse alloc] initWithURL:url
                                  statusCode:200
                                 HTTPVersion:nil
                                headerFields:@{@"Content-Type" : @"image/jpeg"}];
  // By this time we should have capturedCompletionHandler being the callback block for the
  // NSURLSessionDataTask, now feed it with image data to see how the block from
  // loadImageDataWithBlock: would react to it.
  for (int i = 0; i < completionHandlers.count; i++) {
    void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error) =
        completionHandlers[i];
    if (i == 0) {
      capturedCompletionHandler(portraitImageData, successfulHTTPResponse, nil);
    } else {
      capturedCompletionHandler(landscapeImageData, successfulHTTPResponse, nil);
    }
  }
  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testOnlyPortraitImageLoads {
  NSError *customError = [[NSError alloc] initWithDomain:@"Error Domain" code:100 userInfo:nil];
  NSData *portraitImageData = [@"test portrait image data" dataUsingEncoding:NSUTF8StringEncoding];

  // Used to capture both portrait and landscape callbacks.
  NSMutableArray *completionHandlers = [NSMutableArray array];

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(void (^capturedCompletionHandler)(
                              NSData *data, NSURLResponse *response, NSError *error)) {
          [completionHandlers addObject:capturedCompletionHandler];
          return YES;
        }]]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL loadImageDataWithBlock:^(NSData *_Nullable imageData,
                                                            NSData *_Nullable landscapeImageData,
                                                            NSError *error) {
    XCTAssertNil(error);  // no error is reported
    NSString *fetchedPortraitImageDataString = [[NSString alloc] initWithData:imageData
                                                                     encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(@"test portrait image data", fetchedPortraitImageDataString);
    XCTAssertNil(landscapeImageData);

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
  for (int i = 0; i < completionHandlers.count; i++) {
    void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error) =
        completionHandlers[i];
    if (i == 0) {
      capturedCompletionHandler(portraitImageData, successfulHTTPResponse, nil);
    } else {
      capturedCompletionHandler(nil, nil, customError);
    }
  }
  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testOnlyLandscapeLoads {
  NSError *customError = [[NSError alloc] initWithDomain:@"Error Domain" code:100 userInfo:nil];
  NSData *landscapeImageData =
      [@"test landscape image data" dataUsingEncoding:NSUTF8StringEncoding];

  // Used to capture both portrait and landscape callbacks.
  NSMutableArray *completionHandlers = [NSMutableArray array];

  OCMStub([self.mockedNSURLSession
      dataTaskWithRequest:[OCMArg any]
        completionHandler:[OCMArg checkWithBlock:^BOOL(void (^capturedCompletionHandler)(
                              NSData *data, NSURLResponse *response, NSError *error)) {
          [completionHandlers addObject:capturedCompletionHandler];
          return YES;
        }]]);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"image load callback triggered."];
  [_defaultContentDataWithImageURL
      loadImageDataWithBlock:^(NSData *_Nullable imageData, NSData *_Nullable landscapeImageData,
                               NSError *error) {
        XCTAssertNotNil(error);  // Error is reported, no image data is valid.
        XCTAssertNil(imageData);
        XCTAssertNil(landscapeImageData);

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
  for (int i = 0; i < completionHandlers.count; i++) {
    void (^capturedCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error) =
        completionHandlers[i];
    if (i == 0) {
      capturedCompletionHandler(nil, nil, customError);
    } else {
      capturedCompletionHandler(landscapeImageData, successfulHTTPResponse, customError);
    }
  }
  [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
