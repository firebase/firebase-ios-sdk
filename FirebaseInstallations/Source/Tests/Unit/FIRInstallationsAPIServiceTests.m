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
#import "FBLPromise+Testing.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsItem+Tests.h"

#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsErrorUtil.h"
#import "FirebaseInstallations/Source/Library/Errors/FIRInstallationsHTTPError.h"
#import "FirebaseInstallations/Source/Library/InstallationsAPI/FIRInstallationsAPIService.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredAuthToken.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

typedef FBLPromise * (^FIRInstallationsAPIServiceTask)(void);

@interface FIRInstallationsAPIService (Tests)
- (instancetype)initWithURLSession:(NSURLSession *)URLSession
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID;
@end

@interface FIRInstallationsAPIServiceTests : XCTestCase
@property(nonatomic) FIRInstallationsAPIService *service;
@property(nonatomic) id mockURLSession;
@property(nonatomic) NSString *APIKey;
@property(nonatomic) NSString *projectID;
@property(nonatomic) id heartbeatMock;
@end

@implementation FIRInstallationsAPIServiceTests

- (void)setUp {
  self.APIKey = @"api-key";
  self.projectID = @"project-id";
  self.mockURLSession = OCMClassMock([NSURLSession class]);
  self.service = [[FIRInstallationsAPIService alloc] initWithURLSession:self.mockURLSession
                                                                 APIKey:self.APIKey
                                                              projectID:self.projectID];
  self.heartbeatMock = OCMClassMock([FIRHeartbeatInfo class]);
  OCMStub([self.heartbeatMock heartbeatCodeForTag:@"fire-installations"])
      .andDo(^(NSInvocation *invocation) {
        XCTAssertFalse([NSThread isMainThread]);
      })
      .andReturn(FIRHeartbeatInfoCodeCombined);
}

- (void)tearDown {
  self.service = nil;
  self.mockURLSession = nil;
  self.projectID = nil;
  self.APIKey = nil;
  self.heartbeatMock = nil;

  // Wait for any pending promises to complete.
  XCTAssert(FBLWaitForPromisesWithTimeout(2));
}

- (void)testRegisterInstallationSuccess {
  NSString *fixtureName = @"APIRegisterInstallationResponseSuccess.json";
  [self assertRegisterInstallationSuccessWithResponseFixtureName:fixtureName
                                                    responseCode:201
                                             expectedFIDOverride:@"aaaaaaaaaaaaaaaaaaaaaa"];
}

- (void)testRegisterInstallationSuccess_NoFIDInResponse {
  NSString *fixtureName = @"APIRegisterInstallationResponseSuccessNoFID.json";
  [self assertRegisterInstallationSuccessWithResponseFixtureName:fixtureName
                                                    responseCode:201
                                             expectedFIDOverride:nil];
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

- (void)testRefreshAuthTokenSuccess {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  installation.firebaseInstallationID = @"qwertyuiopasdfghjklzxcvbnm";

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation];

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

- (void)testRefreshAuthTokenAPIError {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  installation.firebaseInstallationID = @"qwertyuiopasdfghjklzxcvbnm";

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation];

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
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation];

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
  id URLRequestValidation = [self refreshTokenRequestValidationArgWithInstallation:installation];

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

- (void)testDeleteInstallationSuccess {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self deleteInstallationRequestValidationWithInstallation:installation];

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

- (void)testDeleteInstallationErrorNotFound {
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];

  // 1. Stub URL session:

  // 1.1. URL request validation.
  id URLRequestValidation = [self deleteInstallationRequestValidationWithInstallation:installation];

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
  id URLRequestValidation = [self deleteInstallationRequestValidationWithInstallation:installation];

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

- (id)refreshTokenRequestValidationArgWithInstallation:(FIRInstallationsItem *)installation {
  return [OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    XCTAssertEqualObjects(request.URL.absoluteString,
                          @"https://firebaseinstallations.googleapis.com/v1/projects/project-id/"
                          @"installations/qwertyuiopasdfghjklzxcvbnm/authTokens:generate");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Type"], @"application/json",
                          @"%@", self.name);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"X-Goog-Api-Key"], self.APIKey, @"%@",
                          self.name);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:kFIRInstallationsUserAgentKey],
                          [FIRApp firebaseUserAgent]);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:kFIRInstallationsHeartbeatKey], @"3");
    NSString *expectedAuthHeader =
        [NSString stringWithFormat:@"FIS_v2 %@", installation.refreshToken];
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"Authorization"], expectedAuthHeader, @"%@",
                          self.name);

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

- (id)deleteInstallationRequestValidationWithInstallation:(FIRInstallationsItem *)installation {
  return [OCMArg checkWithBlock:^BOOL(NSURLRequest *request) {
    XCTAssert([request isKindOfClass:[NSURLRequest class]], @"Unexpected class: %@",
              [request class]);
    XCTAssertEqualObjects(request.HTTPMethod, @"DELETE");
    NSString *expectedURL = [NSString
        stringWithFormat:
            @"https://firebaseinstallations.googleapis.com/v1/projects/%@/installations/%@/",
            self.projectID, installation.firebaseInstallationID];
    XCTAssertEqualObjects(request.URL.absoluteString, expectedURL);
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"Content-Type"], @"application/json");
    XCTAssertEqualObjects(request.allHTTPHeaderFields[@"X-Goog-Api-Key"], self.APIKey);

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
                                             expectedFIDOverride:(nullable NSString *)overrideFID {
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
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"Content-Type"], @"application/json");
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"X-Goog-Api-Key"], self.APIKey);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"X-Ios-Bundle-Identifier"],
                          [[NSBundle mainBundle] bundleIdentifier]);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:kFIRInstallationsUserAgentKey],
                          [FIRApp firebaseUserAgent]);
    XCTAssertEqualObjects([request valueForHTTPHeaderField:kFIRInstallationsHeartbeatKey], @"3");

    NSString *expectedIIDMigrationHeader = installation.IIDDefaultToken;
    XCTAssertEqualObjects([request valueForHTTPHeaderField:@"x-goog-fis-ios-iid-migration-auth"],
                          expectedIIDMigrationHeader);

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
