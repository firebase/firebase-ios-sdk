/*
 * Copyright 2019 Google
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

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

@import FirebaseCoreInternal;

#import "FBLPromise+Testing.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsItem+Tests.h"

#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsErrorUtil.h"
#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsHTTPError.h"
#import "FirebaseInstallations/Source/Library/InstallationsAPI/FIRInstallationsAPIService.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredAuthToken.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

typedef FBLPromise * (^FIRInstallationsAPIServiceTask)(void);

#pragma mark - Fakes

/// A fake heartbeat logger used for dependency injection during testing.
@interface FIRHeartbeatLoggerFake : NSObject <FIRHeartbeatLoggerProtocol>
@property(nonatomic, copy, nullable) FIRHeartbeatsPayload * (^onFlushHeartbeatsIntoPayloadHandler)
    (void);
@property(nonatomic, copy, nullable) FIRDailyHeartbeatCode (^onHeartbeatCodeForTodayHandler)(void);
@end

@implementation FIRHeartbeatLoggerFake

- (nonnull FIRHeartbeatsPayload *)flushHeartbeatsIntoPayload {
  if (self.onFlushHeartbeatsIntoPayloadHandler) {
    return self.onFlushHeartbeatsIntoPayloadHandler();
  } else {
    return nil;
  }
}

- (FIRDailyHeartbeatCode)heartbeatCodeForToday {
  // This API should not be used by the below tests because the Installations
  // SDK uses only the V2 heartbeat API (`flushHeartbeatsIntoPayload`) for
  // getting heartbeats.
  [self doesNotRecognizeSelector:_cmd];
  return FIRDailyHeartbeatCodeNone;
}

- (void)log {
  // This API should not be used by the below tests because the Installations
  // SDK does not log heartbeats in it's networking context.
  [self doesNotRecognizeSelector:_cmd];
}

@end

#pragma mark - FIRInstallationsAPIService + Internal

@interface FIRInstallationsAPIService (Internal)
- (instancetype)initWithURLSession:(NSURLSession *)URLSession
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID
                   heartbeatLogger:(id<FIRHeartbeatLoggerProtocol>)heartbeatLogger;
@end

#pragma mark - FIRInstallationsAPIServiceTests

@interface FIRInstallationsAPIServiceTests : XCTestCase
@property(nonatomic) FIRInstallationsAPIService *service;
@property(nonatomic) FIRHeartbeatLoggerFake *heartbeatLoggerFake;
@property(nonatomic) NSString *APIKey;
@property(nonatomic) NSString *projectID;
@property(nonatomic) id mockURLSession;
@end

@implementation FIRInstallationsAPIServiceTests

- (void)setUp {
  self.APIKey = @"api-key";
  self.projectID = @"project-id";
  self.mockURLSession = OCMClassMock([NSURLSession class]);
  self.heartbeatLoggerFake = [[FIRHeartbeatLoggerFake alloc] init];
  self.service = [[FIRInstallationsAPIService alloc] initWithURLSession:self.mockURLSession
                                                                 APIKey:self.APIKey
                                                              projectID:self.projectID
                                                        heartbeatLogger:self.heartbeatLoggerFake];
}

- (void)tearDown {
  self.service = nil;
  self.heartbeatLoggerFake = nil;
  self.mockURLSession = nil;
  self.projectID = nil;
  self.APIKey = nil;

  // Wait for any pending promises to complete.
  XCTAssert(FBLWaitForPromisesWithTimeout(2));
}

- (void)testRegisterInstallationSuccessWhenHeartbeatsNeedSending {
  // Given
  NSString *fixtureName = @"APIRegisterInstallationResponseSuccess.json";
  FIRHeartbeatsPayload *nonEmptyHeartbeatsPayload =
      [FIRHeartbeatLoggingTestUtils nonEmptyHeartbeatsPayload];
  // When
  self.heartbeatLoggerFake.onFlushHeartbeatsIntoPayloadHandler = ^FIRHeartbeatsPayload * {
    return nonEmptyHeartbeatsPayload;
  };
  // Then
  [self assertRegisterInstallationSuccessWithResponseFixtureName:fixtureName
                                                    responseCode:201
                                             expectedFIDOverride:@"aaaaaaaaaaaaaaaaaaaaaa"
                                               heartbeatsPayload:nonEmptyHeartbeatsPayload];
}

- (void)testRegisterInstallationSuccessWhenNoHeartbeatsNeedSending {
  // Given
  NSString *fixtureName = @"APIRegisterInstallationResponseSuccess.json";
  FIRHeartbeatsPayload *emptyHeartbeatsPayload =
      [FIRHeartbeatLoggingTestUtils emptyHeartbeatsPayload];
  // When
  self.heartbeatLoggerFake.onFlushHeartbeatsIntoPayloadHandler = ^FIRHeartbeatsPayload * {
    return emptyHeartbeatsPayload;
  };
  // Then
  [self assertRegisterInstallationSuccessWithResponseFixtureName:fixtureName
                                                    responseCode:201
                                             expectedFIDOverride:@"aaaaaaaaaaaaaaaaaaaaaa"
                                               heartbeatsPayload:emptyHeartbeatsPayload];
}

- (void)testRegisterInstallationSuccess_NoFIDInResponse {
  NSString *fixtureName = @"APIRegisterInstallationResponseSuccessNoFID.json";
  [self assertRegisterInstallationSuccessWithResponseFixtureName:fixtureName
                                                    responseCode:201
                                             expectedFIDOverride:nil
                                               heartbeatsPayload:nil];
}

- (void)testRegisterInstallationSuccess_InvalidInstallation {
  FIRInstallationsItem *installation = [FIRInstallationsItem createUnregisteredInstallationItem];
  installation.firebaseInstallationID = nil;

  __auto_type promise = [self.service registerInstallation:installation];

  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue(promise.isRejected);
  XCTAssertNil(promise.value);
  XCTAssertNotNil(promise.error);
}

- (void)testRefreshAuthTokenSuccessWhenHeartbeatsNeedSending {
  // Given
  FIRHeartbeatsPayload *nonEmptyHeartbeatsPayload =
      [FIRHeartbeatLoggingTestUtils nonEmptyHeartbeatsPayload];
  // When
  self.heartbeatLoggerFake.onFlushHeartbeatsIntoPayloadHandler = ^FIRHeartbeatsPayload * {
    return nonEmptyHeartbeatsPayload;
  };
  // Then
  [self assertRefreshAuthTokenSuccessWhenSendingHeartbeatsPayload:nonEmptyHeartbeatsPayload];
}

- (void)testRefreshAuthTokenSuccessWhenNoHeartbeatsNeedSending {
  // Given
  FIRHeartbeatsPayload *emptyHeartbeatsPayload =
      [FIRHeartbeatLoggingTestUtils emptyHeartbeatsPayload];
  // When
  self.heartbeatLoggerFake.onFlushHeartbeatsIntoPayloadHandler = ^FIRHeartbeatsPayload * {
    return emptyHeartbeatsPayload;
  };
  // Then
  [self assertRefreshAuthTokenSuccessWhenSendingHeartbeatsPayload:emptyHeartbeatsPayload];
}

- (void)testRefreshAuthTokenAPIError {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  installation.firebaseInstallationID = @"qwertyuiopasdfghjklzxcvbnm";

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation
                                                                 heartbeatsPayload:nil];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // 1.5. Prepare server response data.
  NSData *errorResponseData =
      [self loadFixtureNamed:@"APIGenerateTokenResponseInvalidRefreshToken.json"];

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise =
      [self.service refreshAuthTokenForInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask, 0.5);

  // 5. Call the data task completion.
  taskCompletion(errorResponseData, [self responseWithStatusCode:401], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue([FIRInstallationsErrorUtil isAPIError:promise.error withHTTPCode:401]);
  XCTAssertNil(promise.value);
}

- (void)testRefreshAuthToken_WhenAPIError500_ThenRetriesOnce {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  installation.firebaseInstallationID = @"qwertyuiopasdfghjklzxcvbnm";

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation
                                                                 heartbeatsPayload:nil];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask1 = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask1 resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask1);

  // 1.5. Prepare server response data.
  NSData *errorResponseData =
      [self loadFixtureNamed:@"APIGenerateTokenResponseInvalidRefreshToken.json"];

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise =
      [self.service refreshAuthTokenForInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask1, 0.5);

  // 5. Call the data task completion.
  taskCompletion(errorResponseData,
                 [self responseWithStatusCode:FIRInstallationsHTTPCodesServerInternalError], nil);

  // 6. Retry:

  // 6.1. Expect another API request to be sent.
  id mockDataTask2 = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask2 resume]);
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask2);
  OCMVerifyAllWithDelay(self.mockURLSession, 1.5);
  OCMVerifyAllWithDelay(mockDataTask2, 1.5);

  // 6.2. Send the API response again.
  taskCompletion(errorResponseData,
                 [self responseWithStatusCode:FIRInstallationsHTTPCodesServerInternalError], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue([FIRInstallationsErrorUtil
        isAPIError:promise.error
      withHTTPCode:FIRInstallationsHTTPCodesServerInternalError]);
  XCTAssertNil(promise.value);
}

- (void)testRefreshAuthTokenDataNil {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  installation.firebaseInstallationID = @"qwertyuiopasdfghjklzxcvbnm";

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation
                                                                 heartbeatsPayload:nil];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise =
      [self.service refreshAuthTokenForInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask, 0.5);

  // 5. Call the data task completion.
  // HTTP 200 but no data (a potential server failure).
  taskCompletion(nil, [self responseWithStatusCode:200], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertEqualObjects(promise.error.userInfo[NSLocalizedFailureReasonErrorKey],
                        @"Failed to serialize JSON data.");
  XCTAssertNil(promise.value);
}

- (void)testDeleteInstallationSuccessWhenHeartbeatsNeedSending {
  // Given
  FIRHeartbeatsPayload *nonEmptyHeartbeatsPayload =
      [FIRHeartbeatLoggingTestUtils nonEmptyHeartbeatsPayload];
  // When
  self.heartbeatLoggerFake.onFlushHeartbeatsIntoPayloadHandler = ^FIRHeartbeatsPayload * {
    return nonEmptyHeartbeatsPayload;
  };
  // Then
  [self assertDeleteInstallationSuccessWhenSendingHeartbeatsPayload:nonEmptyHeartbeatsPayload];
}

- (void)testDeleteInstallationSuccessWhenNoHeartbeatsNeedSending {
  // Given
  FIRHeartbeatsPayload *emptyHeartbeatsPayload =
      [FIRHeartbeatLoggingTestUtils emptyHeartbeatsPayload];
  // When
  self.heartbeatLoggerFake.onFlushHeartbeatsIntoPayloadHandler = ^FIRHeartbeatsPayload * {
    return emptyHeartbeatsPayload;
  };
  // Then
  [self assertDeleteInstallationSuccessWhenSendingHeartbeatsPayload:emptyHeartbeatsPayload];
}

- (void)testDeleteInstallationErrorNotFound {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self deleteInstallationRequestValidationWithInstallation:installation
                                                                    heartbeatsPayload:nil];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise = [self.service deleteInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask, 0.5);

  // 5. Call the data task completion.
  // HTTP 200 but no data (a potential server failure).
  taskCompletion(nil, [self responseWithStatusCode:404], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue([FIRInstallationsErrorUtil isAPIError:promise.error withHTTPCode:404]);
  XCTAssertNil(promise.value);
}

- (void)testDeleteInstallation_WhenAPIError500_ThenRetriesOnce {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self deleteInstallationRequestValidationWithInstallation:installation
                                                                    heartbeatsPayload:nil];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask1 = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask1 resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask1);

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise = [self.service deleteInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask1, 0.5);

  // 5. Call the data task completion.
  // HTTP 200 but no data (a potential server failure).
  taskCompletion(nil, [self responseWithStatusCode:FIRInstallationsHTTPCodesServerInternalError],
                 nil);

  // 6. Retry:
  // 6.1. Wait for the API request to be sent again.
  id mockDataTask2 = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask2 resume]);
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask2);
  OCMVerifyAllWithDelay(self.mockURLSession, 1.5);
  OCMVerifyAllWithDelay(mockDataTask1, 1.5);

  // 6.1. Send another response.
  taskCompletion(nil, [self responseWithStatusCode:FIRInstallationsHTTPCodesServerInternalError],
                 nil);

  // 7. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertTrue([FIRInstallationsErrorUtil
        isAPIError:promise.error
      withHTTPCode:FIRInstallationsHTTPCodesServerInternalError]);
  XCTAssertNil(promise.value);
}

#pragma mark - Helpers

- (void)assertRefreshAuthTokenSuccessWhenSendingHeartbeatsPayload:
    (FIRHeartbeatsPayload *)heartbeatsPayload {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  installation.firebaseInstallationID = @"qwertyuiopasdfghjklzxcvbnm";

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation =
      [self refreshTokenRequestValidationArgWithInstallation:installation
                                           heartbeatsPayload:heartbeatsPayload];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // 1.5. Prepare server response data.
  NSData *successResponseData = [self loadFixtureNamed:@"APIGenerateTokenResponseSuccess.json"];

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise =
      [self.service refreshAuthTokenForInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask, 0.5);

  // 5. Call the data task completion.
  taskCompletion(successResponseData, [self responseWithStatusCode:200], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertNotEqual(promise.value, installation);
  XCTAssertEqualObjects(promise.value.appID, installation.appID);
  XCTAssertEqualObjects(promise.value.firebaseAppName, installation.firebaseAppName);
  XCTAssertEqualObjects(promise.value.firebaseInstallationID, installation.firebaseInstallationID);
  XCTAssertEqualObjects(promise.value.refreshToken, installation.refreshToken);
  XCTAssertEqualObjects(promise.value.authToken.token,
                        @"aaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbb.cccccccccccccccccccccccc");
  [self assertDate:promise.value.authToken.expirationDate
      isApproximatelyEqualCurrentPlusTimeInterval:3987465];
}

- (void)assertDeleteInstallationSuccessWhenSendingHeartbeatsPayload:
    (FIRHeartbeatsPayload *)heartbeatsPayload {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation =
      [self deleteInstallationRequestValidationWithInstallation:installation
                                              heartbeatsPayload:heartbeatsPayload];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise = [self.service deleteInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask, 0.5);

  // 5. Call the data task completion.
  // HTTP 200 but no data (a potential server failure).
  NSData *successResponseData = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
  taskCompletion(successResponseData, [self responseWithStatusCode:200], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertEqual(promise.value, installation);
}

- (NSData *)loadFixtureNamed:(NSString *)fileName {
  NSURL *fileURL = [[NSBundle bundleForClass:[self class]] URLForResource:fileName
                                                            withExtension:nil];
  XCTAssertNotNil(fileURL);

  NSError *error;
  NSData *data = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
  XCTAssertNotNil(data, @"File name: %@ Error: %@", fileName, error);

  return data;
}

- (NSURLResponse *)responseWithStatusCode:(NSUInteger)statusCode {
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:[NSURL fileURLWithPath:@"/"]
                                                            statusCode:statusCode
                                                           HTTPVersion:nil
                                                          headerFields:nil];
  return response;
}

- (void)assertDate:(NSDate *)date
    isApproximatelyEqualCurrentPlusTimeInterval:(NSTimeInterval)timeInterval {
  NSDate *expectedDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];

  NSTimeInterval precision = 10;
  XCTAssert(ABS([date timeIntervalSinceDate:expectedDate]) <= precision,
            @"date: %@ is not equal to expected %@ with precision %f - %@", date, expectedDate,
            precision, self.name);
}

- (id)refreshTokenRequestValidationArgWithInstallation:(FIRInstallationsItem *)installation
                                     heartbeatsPayload:(FIRHeartbeatsPayload *)heartbeatsPayload {
  return [OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    XCTAssertEqualObjects(request.URL.absoluteString,
                          @"https://firebaseinstallations.googleapis.com/v1/projects/project-id/"
                          @"installations/qwertyuiopasdfghjklzxcvbnm/authTokens:generate");

    NSMutableDictionary<NSString *, NSString *> *expectedHTTPHeaderFields = @{
      @"Content-Type" : @"application/json",
      @"X-Goog-Api-Key" : self.APIKey,
      @"X-Ios-Bundle-Identifier" : [[NSBundle mainBundle] bundleIdentifier],
      @"Authorization" : [NSString stringWithFormat:@"FIS_v2 %@", installation.refreshToken]
    }
                                                                                .mutableCopy;

    NSString *_Nullable heartbeatHeaderValue =
        FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload);
    if (heartbeatHeaderValue) {
      expectedHTTPHeaderFields[@"X-firebase-client"] = heartbeatHeaderValue;
    }

    XCTAssertEqualObjects([request allHTTPHeaderFields], expectedHTTPHeaderFields);

    NSError *error;
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                         options:0
                                                           error:&error];
    XCTAssertNotNil(body, @"Error: %@, test: %@", error, self.name);

    XCTAssertEqualObjects(
        body,
        @{@"installation" : @{@"sdkVersion" : [self SDKVersion]}}, @"%@", self.name);

    return YES;
  }];
}

- (id)deleteInstallationRequestValidationWithInstallation:(FIRInstallationsItem *)installation
                                        heartbeatsPayload:
                                            (FIRHeartbeatsPayload *)heartbeatsPayload {
  return [OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
    XCTAssert([request isKindOfClass:[NSURLRequest class]], @"Unexpected class: %@",
              [request class]);
    XCTAssertEqualObjects(request.HTTPMethod, @"DELETE");
    NSString *expectedURL = [NSString
        stringWithFormat:
            @"https://firebaseinstallations.googleapis.com/v1/projects/%@/installations/%@/",
            self.projectID, installation.firebaseInstallationID];
    XCTAssertEqualObjects(request.URL.absoluteString, expectedURL);

    NSMutableDictionary<NSString *, NSString *> *expectedHTTPHeaderFields = @{
      @"Content-Type" : @"application/json",
      @"X-Goog-Api-Key" : self.APIKey,
      @"X-Ios-Bundle-Identifier" : [[NSBundle mainBundle] bundleIdentifier],
      @"Authorization" : [NSString stringWithFormat:@"FIS_v2 %@", installation.refreshToken],
    }
                                                                                .mutableCopy;

    NSString *_Nullable heartbeatHeaderValue =
        FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload);
    if (heartbeatHeaderValue) {
      expectedHTTPHeaderFields[@"X-firebase-client"] = heartbeatHeaderValue;
    }

    XCTAssertEqualObjects([request allHTTPHeaderFields], expectedHTTPHeaderFields);

    NSString *expectedAuthHeader =
        [NSString stringWithFormat:@"FIS_v2 %@", installation.refreshToken];
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"Authorization"], expectedAuthHeader, @"%@",
                          self.name);

    NSError *error;
    NSDictionary *JSONBody = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                             options:0
                                                               error:&error];
    XCTAssertNotNil(JSONBody, @"Error: %@", error);
    XCTAssertEqualObjects(JSONBody, @{});

    return YES;
  }];
}

- (void)assertRegisterInstallationSuccessWithResponseFixtureName:(NSString *)fixtureName
                                                    responseCode:(NSInteger)responseCode
                                             expectedFIDOverride:(nullable NSString *)overrideFID
                                               heartbeatsPayload:
                                                   (FIRHeartbeatsPayload *)heartbeatsPayload {
  FIRInstallationsItem *installation = [FIRInstallationsItem createUnregisteredInstallationItem];
  installation.IIDDefaultToken = @"iid-auth-token";

  NSString *expectedFID = overrideFID ?: installation.firebaseInstallationID;

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    XCTAssertEqualObjects(
        request.URL.absoluteString,
        @"https://firebaseinstallations.googleapis.com/v1/projects/project-id/installations/");

    NSMutableDictionary<NSString *, NSString *> *expectedHTTPHeaderFields = @{
      @"Content-Type" : @"application/json",
      @"X-Goog-Api-Key" : self.APIKey,
      @"X-Ios-Bundle-Identifier" : [[NSBundle mainBundle] bundleIdentifier],
    }
                                                                                .mutableCopy;

    NSString *_Nullable heartbeatHeaderValue =
        FIRHeaderValueFromHeartbeatsPayload(heartbeatsPayload);
    if (heartbeatHeaderValue) {
      expectedHTTPHeaderFields[@"X-firebase-client"] = heartbeatHeaderValue;
    }

    [expectedHTTPHeaderFields addEntriesFromDictionary:@{
      @"x-goog-fis-ios-iid-migration-auth" : installation.IIDDefaultToken
    }];

    XCTAssertEqualObjects([request allHTTPHeaderFields], expectedHTTPHeaderFields);

    NSError *error;
    NSDictionary *body = [NSJSONSerialization JSONObjectWithData:request.HTTPBody
                                                         options:0
                                                           error:&error];
    XCTAssertNotNil(body, @"Error: %@", error);

    XCTAssertEqualObjects(body[@"fid"], installation.firebaseInstallationID);
    XCTAssertEqualObjects(body[@"authVersion"], @"FIS_v2");
    XCTAssertEqualObjects(body[@"appId"], installation.appID);

    XCTAssertEqualObjects(body[@"sdkVersion"], [self SDKVersion]);

    return YES;
  }];

  // 1.2. Capture completion to call it later.
  __block void (^taskCompletion)(NSData *, NSURLResponse *, NSError *);
  id completionArg = [OCMArg checkWithBlock:^BOOL(id obj) {
    taskCompletion = obj;
    return YES;
  }];

  // 1.3. Create a data task mock.
  id mockDataTask = OCMClassMock([NSURLSessionDataTask class]);
  OCMExpect([(NSURLSessionDataTask *)mockDataTask resume]);

  // 1.4. Expect `dataTaskWithRequest` to be called.
  OCMExpect([self.mockURLSession dataTaskWithRequest:URLRequestValidation
                                   completionHandler:completionArg])
      .andReturn(mockDataTask);

  // 2. Call
  FBLPromise<FIRInstallationsItem *> *promise = [self.service registerInstallation:installation];

  // 3. Wait for `[NSURLSession dataTaskWithRequest...]` to be called
  OCMVerifyAllWithDelay(self.mockURLSession, 0.5);

  // 4. Wait for the data task `resume` to be called.
  OCMVerifyAllWithDelay(mockDataTask, 0.5);

  // 5. Call the data task completion.
  NSData *responseData = [self loadFixtureNamed:fixtureName];
  taskCompletion(responseData, [self responseWithStatusCode:responseCode], nil);

  // 6. Check result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertNotEqual(promise.value, installation);
  XCTAssertEqualObjects(promise.value.appID, installation.appID);
  XCTAssertEqualObjects(promise.value.firebaseAppName, installation.firebaseAppName);

  // Server may respond with a different FID if the sent FID cannot be accepted.
  XCTAssertEqualObjects(promise.value.firebaseInstallationID, expectedFID);
  XCTAssertEqualObjects(promise.value.refreshToken, @"aaaaaaabbbbbbbbcccccccccdddddddd00000000");
  XCTAssertEqualObjects(promise.value.authToken.token,
                        @"aaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbb.cccccccccccccccccccccccc");
  [self assertDate:promise.value.authToken.expirationDate
      isApproximatelyEqualCurrentPlusTimeInterval:604800];
}

- (NSString *)SDKVersion {
  return [NSString stringWithFormat:@"i:%@", FIRFirebaseVersion()];
}

@end
