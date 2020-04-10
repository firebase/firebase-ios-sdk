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

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthRPCRequest.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthRPCResponse.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthRequestConfiguration.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"
#import "FirebaseAuth/Sources/Utilities/FIRAuthInternalErrors.h"
#import "FirebaseAuth/Tests/Unit/FIRFakeBackendRPCIssuer.h"

/** @var kFakeRequestURL
    @brief Used as a fake URL for a fake RPC request. We don't test this here, since it's tested
        for the specific RPC requests in their various unit tests.
 */
static NSString *const kFakeRequestURL = @"https://www.google.com/";

/** @var kFakeAPIkey
    @brief Used as a fake APIKey for a fake RPC request. We don't test this here.
 */
static NSString *const kFakeAPIkey = @"FAKE_API_KEY";

/** @var kFakeErrorDomain
    @brief A value to use for fake @c NSErrors.
 */
static NSString *const kFakeErrorDomain = @"fakeDomain";

/** @var kFakeErrorCode
    @brief A value to use for fake @c NSErrors.
 */
static const NSUInteger kFakeErrorCode = -1;

/** @var kUnknownServerErrorMessage
    @brief A value to use for fake server errors with an unknown message.
 */
static NSString *const kUnknownServerErrorMessage = @"UNKNOWN_MESSAGE";

/** @var kErrorMessageCaptchaRequired
    @brief The error message in JSON responses from the server for CAPTCHA required.
 */
static NSString *const kErrorMessageCaptchaRequired = @"CAPTCHA_REQUIRED";

/** @var kErrorMessageCaptchaRequiredInvalidPassword
    @brief The error message in JSON responses from the server for CAPTCHA required with invalid
        password.
 */
static NSString *const kErrorMessageCaptchaRequiredInvalidPassword =
    @"CAPTCHA_REQUIRED_INVALID_PASSWORD";

/** @var kErrorMessageCaptchaCheckFailed
    @brief The error message in JSON responses from the server for CAPTCHA check failed.
 */
static NSString *const kErrorMessageCaptchaCheckFailed = @"CAPTCHA_CHECK_FAILED";

/** @var kErrorMessageEmailExists
    @brief The error message in JSON responses from the server for user's email already exists.
 */
static NSString *const kErrorMessageEmailExists = @"EMAIL_EXISTS";

/** @var kErrorMessageKey
    @brief The key for the error message in an error response.
 */
static NSString *const kErrorMessageKey = @"message";

/** @var kTestKey
    @brief A key to use for a successful response dictionary.
 */
static NSString *const kTestKey = @"TestKey";

/** @var kUserDisabledErrorMessage
    @brief This is the base error message the server will respond with if the user's account has
        been disabled.
 */
static NSString *const kUserDisabledErrorMessage = @"USER_DISABLED";

/** @var kFakeUserDisabledCustomErrorMessage
    @brief This is a fake custom error message the server can respond with if the user's account has
        been disabled.
 */
static NSString *const kFakeUserDisabledCustomErrorMessage = @"The user has been disabled.";

/** @var kServerErrorDetailMarker
    @brief This marker indicates that the server error message contains a detail error message which
        should be used instead of the hardcoded client error message.
 */
static NSString *const kServerErrorDetailMarker = @" : ";

/** @var kTestValue
    @brief A value to use for a successful response dictionary.
 */
static NSString *const kTestValue = @"TestValue";

/** @class FIRAuthBackendRPCImplementation
    @brief Exposes an otherwise private class to these tests. See the real implementation for
        documentation.
 */
@interface FIRAuthBackendRPCImplementation : NSObject <FIRAuthBackendImplementation>

/** @fn postWithRequest:response:callback:
    @brief Calls the RPC using HTTP POST.
    @remarks Possible error responses:
        @see FIRAuthInternalErrorCodeRPCRequestEncodingError
        @see FIRAuthInternalErrorCodeJSONSerializationError
        @see FIRAuthInternalErrorCodeNetworkError
        @see FIRAuthInternalErrorCodeUnexpectedErrorResponse
        @see FIRAuthInternalErrorCodeUnexpectedResponse
        @see FIRAuthInternalErrorCodeRPCResponseDecodingError
    @param request The request.
    @param response The empty response to be filled.
    @param callback The callback for both success and failure.
 */
- (void)postWithRequest:(id<FIRAuthRPCRequest>)request
               response:(id<FIRAuthRPCResponse>)response
               callback:(void (^)(NSError *error))callback;

@end

/** @class FIRFakeRequest
    @brief Allows us to fake a request with deterministic request bodies and encoding errors
        returned from the @c FIRAuthRPCRequest-specified @c unencodedHTTPRequestBodyWithError:
        method.
 */
@interface FIRFakeRequest : NSObject <FIRAuthRPCRequest>

/** @fn fakeRequest
    @brief A "normal" request which returns an encodable request object with no error.
 */
+ (nullable instancetype)fakeRequest;

/** @fn fakeRequestWithEncodingError
    @brief A request which returns a fake error during the encoding process.
 */
+ (nullable instancetype)fakeRequestWithEncodingError:(NSError *)error;

/** @fn fakeRequestWithUnserializableRequestBody
    @brief A request which returns a request object which can not be properly serialized by
        @c NSJSONSerialization.
 */
+ (nullable instancetype)fakeRequestWithUnserializableRequestBody;

/** @fn fakeRequestWithNoBody
    @brief A request which returns a nil request body but no error.
 */
+ (nullable instancetype)fakeRequestWithNoBody;

/** @fn init
    @brief Please use initWithRequestBody:encodingError:
 */
- (nullable instancetype)init NS_UNAVAILABLE;

/** @fn initWithRequestBody:encodingError:
    @brief Designated initializer.
    @param requestBody The fake request body to return when @c unencodedHTTPRequestBodyWithError: is
        invoked.
    @param encodingError The fake error to return when @c unencodedHTTPRequestBodyWithError is
        invoked.
 */
- (nullable instancetype)initWithRequestBody:(nullable id)requestBody
                               encodingError:(nullable NSError *)encodingError
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRFakeRequest {
  /** @var _requestBody
      @brief The fake request body object we will return when @c unencodedHTTPRequestBodyWithError:
          is invoked.
   */
  id _Nullable _requestBody;

  /** @var _requestEncodingError
      @brief The fake error object we will return when @c unencodedHTTPRequestBodyWithError:
          is invoked.
   */
  NSError *_Nullable _requestEncodingError;
}

+ (nullable instancetype)fakeRequest {
  return [[self alloc] initWithRequestBody:@{} encodingError:nil];
}

+ (nullable instancetype)fakeRequestWithEncodingError:(NSError *)error {
  return [[self alloc] initWithRequestBody:nil encodingError:error];
}

+ (nullable instancetype)fakeRequestWithUnserializableRequestBody {
  return [[self alloc] initWithRequestBody:@{@"unencodableValue" : self} encodingError:nil];
}

+ (nullable instancetype)fakeRequestWithNoBody {
  return [[self alloc] initWithRequestBody:nil encodingError:nil];
}

- (nullable instancetype)initWithRequestBody:(nullable id)requestBody
                               encodingError:(nullable NSError *)encodingError {
  self = [super init];
  if (self) {
    _requestBody = requestBody;
    _requestEncodingError = encodingError;
  }
  return self;
}

- (NSURL *)requestURL {
  return [NSURL URLWithString:kFakeRequestURL];
}

- (BOOL)containsPostBody {
  return YES;
}

- (FIRAuthRequestConfiguration *)requestConfiguration {
  FIRAuthRequestConfiguration *fakeConfiguration =
      [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kFakeAPIkey];
  return fakeConfiguration;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *_Nullable *_Nullable)error {
  if (error) {
    *error = _requestEncodingError;
  }
  return _requestBody;
}

@end

/** @class FIRFakeResponse
    @brief Allows us to inspect the dictionaries received by @c FIRAuthRPCResponse classes, and
        provide deterministic responses to the @c setWithDictionary:error:
        methods.
 */
@interface FIRFakeResponse : NSObject <FIRAuthRPCResponse>

/** @property receivedDictionary
    @brief The dictionary passed to the @c setWithDictionary:error: method.
 */
@property(nonatomic, strong, readonly, nullable) NSDictionary *receivedDictionary;

/** @fn fakeResponse
    @brief A "normal" sucessful response (no error, no expected kind.)
 */
+ (nullable instancetype)fakeResponse;

/** @fn fakeResponseWithDecodingError
    @brief A response which returns a fake error during the decoding process.
 */
+ (nullable instancetype)fakeResponseWithDecodingError;

/** @fn init
    @brief Please use initWithDecodingError:
 */
- (nullable instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithDecodingError:(nullable NSError *)decodingError
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FIRFakeResponse {
  /** @var _responseDecodingError
      @brief The value to return for an error when the @c setWithDictionary:error: method is
          invoked.
   */
  NSError *_Nullable _responseDecodingError;
}

+ (nullable instancetype)fakeResponse {
  return [[self alloc] initWithDecodingError:nil];
}

+ (nullable instancetype)fakeResponseWithDecodingError {
  NSError *decodingError = [FIRAuthErrorUtils unexpectedErrorResponseWithDeserializedResponse:self];
  return [[self alloc] initWithDecodingError:decodingError];
}

- (nullable instancetype)initWithDecodingError:(nullable NSError *)decodingError {
  self = [super init];
  if (self) {
    _responseDecodingError = decodingError;
  }
  return self;
}

- (BOOL)setWithDictionary:(NSDictionary *)dictionary error:(NSError *_Nullable *_Nullable)error {
  if (_responseDecodingError) {
    if (error) {
      *error = _responseDecodingError;
    }
    return NO;
  }
  _receivedDictionary = dictionary;
  return YES;
}

@end

/** @class FIRAuthBackendRPCImplementationTests
    @brief This set of unit tests is designed primarily to test the possible outcomes of the
        @c FIRAuthBackendRPCImplementation.postWithRequest:response:callback: method.
 */
@interface FIRAuthBackendRPCImplementationTests : XCTestCase
@end
@implementation FIRAuthBackendRPCImplementationTests {
  /** @var _RPCIssuer
      @brief This backend RPC issuer is used to fake network responses for each test in the suite.
          In the @c setUp method we initialize this and set @c FIRAuthBackend's RPC issuer to it.
   */
  FIRFakeBackendRPCIssuer *_RPCIssuer;

  /** @var _RPCImplementation
      @brief This backend RPC implementation is used to make fake network requests for each test in
          the suite.
   */
  FIRAuthBackendRPCImplementation *_RPCImplementation;
}

- (void)setUp {
  FIRFakeBackendRPCIssuer *RPCIssuer = [[FIRFakeBackendRPCIssuer alloc] init];
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:RPCIssuer];
  _RPCIssuer = RPCIssuer;
  _RPCImplementation = [FIRAuthBackend implementation];
}

- (void)tearDown {
  [FIRAuthBackend setDefaultBackendImplementationWithRPCIssuer:nil];
  _RPCIssuer = nil;
  _RPCImplementation = nil;
}

/** @fn testRequestEncodingError
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        request passed returns an error during it's unencodedHTTPRequestBodyWithError: method.
        The error returned should be delivered to the caller without any change.
 */
- (void)testRequestEncodingError {
  NSError *encodingError = [NSError errorWithDomain:kFakeErrorDomain
                                               code:kFakeErrorCode
                                           userInfo:@{}];
  FIRFakeRequest *request = [FIRFakeRequest fakeRequestWithEncodingError:encodingError];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // There is no need to call [_RPCIssuer respondWithError:...] in this test because a request
  // should never have been tried - and we we know that's the case when we test @c callbackInvoked.

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeRPCRequestEncodingError);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingUnderlyingError);
  XCTAssertEqualObjects(underlyingUnderlyingError.domain, kFakeErrorDomain);
  XCTAssertEqual(underlyingUnderlyingError.code, kFakeErrorCode);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNil(deserializedResponse);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testBodyDataSerializationError
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        request returns an object which isn't serializable by @c NSJSONSerialization.
        The error from @c NSJSONSerialization should be returned as the underlyingError for an
        @c NSError with the code @c FIRAuthErrorCodeJSONSerializationError.
 */
- (void)testBodyDataSerializationError {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequestWithUnserializableRequestBody];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // There is no need to call [_RPCIssuer respondWithError:...] in this test because a request
  // should never have been tried - and we we know that's the case when we test @c callbackInvoked.

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeJSONSerializationError);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNil(deserializedResponse);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testNetworkError
    @brief This test checks to make sure a network error is properly wrapped and forwarded with the
        correct code (FIRAuthErrorCodeNetworkError).
 */
- (void)testNetworkError {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // It shouldn't matter what the error domain/code/userInfo are, any junk values are suitable. The
  // implementation should treat any error with no response data as a network error.
  NSError *responseError = [NSError errorWithDomain:kFakeErrorDomain
                                               code:kFakeErrorCode
                                           userInfo:nil];
  [_RPCIssuer respondWithError:responseError];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeNetworkError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, kFakeErrorDomain);
  XCTAssertEqual(underlyingError.code, kFakeErrorCode);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNil(deserializedResponse);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testUnparsableErrorResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response isn't deserializable by @c NSJSONSerialization and an error
        condition (with an associated error response message) was expected. We are expecting to
        receive the original network error wrapped in an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedHTTPResponse.
 */
- (void)testUnparsableErrorResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  NSData *data =
      [@"<html><body>An error occurred.</body></html>" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithData:data error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedErrorResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingUnderlyingError);
  XCTAssertEqualObjects(underlyingUnderlyingError.domain, kFakeErrorDomain);
  XCTAssertEqual(underlyingUnderlyingError.code, kFakeErrorCode);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNil(deserializedResponse);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNotNil(dataResponse);
  XCTAssertEqualObjects(dataResponse, data);
}

/** @fn testUnparsableSuccessResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response isn't deserializable by @c NSJSONSerialization and no error
        condition was indicated. We are expecting to
        receive the @c NSJSONSerialization error wrapped in an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedServerResponse.
 */
- (void)testUnparsableSuccessResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  NSData *data = [@"<xml>Some non-JSON value.</xml>" dataUsingEncoding:NSUTF8StringEncoding];
  [_RPCIssuer respondWithData:data error:nil];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingUnderlyingError);
  XCTAssertEqualObjects(underlyingUnderlyingError.domain, NSCocoaErrorDomain);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNil(deserializedResponse);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNotNil(dataResponse);
  XCTAssertEqualObjects(dataResponse, data);
}

/** @fn testNonDictionaryErrorResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response deserialized by @c NSJSONSerialization is not a dictionary, and an error was
        expected. We are expecting to receive an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedErrorServerResponse with the decoded response in the
        @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedResponseKey.
 */
- (void)testNonDictionaryErrorResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // We are responding with a JSON-encoded string value representing an array - which is unexpected.
  // It should normally be a dictionary, and we need to check for this sort of thing. Because we can
  // successfully decode this value, however, we do return it in the error results. We check for
  // this array later in the test.
  NSData *data = [@"[]" dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithData:data error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedErrorResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSArray class]]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testNonDictionarySuccessResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response deserialized by @c NSJSONSerialization is not a dictionary, and no error was
        expected. We are expecting to receive an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded response in the
        @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedResponseKey.
 */
- (void)testNonDictionarySuccessResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // We are responding with a JSON-encoded string value representing an array - which is unexpected.
  // It should normally be a dictionary, and we need to check for this sort of thing. Because we can
  // successfully decode this value, however, we do return it in the error results. We check for
  // this array later in the test.
  NSData *data = [@"[]" dataUsingEncoding:NSUTF8StringEncoding];
  [_RPCIssuer respondWithData:data error:nil];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSArray class]]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testCaptchaRequiredResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        we get an error message indicating captcha is required. The backend should not be returning
        this error to mobile clients. If it does, we should wrap it in an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded error message in the
        @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedErrorResponseKey.
 */
- (void)testCaptchaRequiredResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithServerErrorMessage:kErrorMessageCaptchaRequired error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedErrorResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSDictionary class]]);
  XCTAssertNotNil(deserializedResponse[@"message"]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testCaptchaCheckFailedResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        we get an error message indicating captcha check failed. The backend should not be returning
        this error to mobile clients. If it does, we should wrap it in an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded error message in the
        @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedErrorResponseKey.
 */
- (void)testCaptchaCheckFailedResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithServerErrorMessage:kErrorMessageCaptchaCheckFailed error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeCaptchaCheckFailed);
}

/** @fn testCaptchaRequiredInvalidPasswordResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        we get an error message indicating captcha is required and an invalid password was entered.
        The backend should not be returning this error to mobile clients. If it does, we should wrap
        it in an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded error message in the
        @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedErrorResponseKey.
 */
- (void)testCaptchaRequiredInvalidPasswordResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithServerErrorMessage:kErrorMessageCaptchaRequiredInvalidPassword
                                      error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedErrorResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSDictionary class]]);
  XCTAssertNotNil(deserializedResponse[@"message"]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testDecodableErrorResponseWithUnknownMessage
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response deserialized by @c NSJSONSerialization represents a valid error response (and an
        error was indicated) but we didn't receive an error message we know about. We are expecting
        an @c NSError with the code @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded
        error message in the @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedErrorResponseKey.
 */
- (void)testDecodableErrorResponseWithUnknownMessage {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // We need to return a valid "error" response here, but we are going to intentionally use a bogus
  // error message.
  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithServerErrorMessage:kUnknownServerErrorMessage error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedErrorResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSDictionary class]]);
  XCTAssertNotNil(deserializedResponse[@"message"]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testErrorResponseWithNoErrorMessage
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response deserialized by @c NSJSONSerialization is a dictionary, and an error was indicated,
        but no error information was present in the decoded response. We are expecting an @c NSError
        with the code @c FIRAuthErrorCodeUnexpectedServerResponse with the decoded
        response message in the @c NSError.userInfo dictionary associated with the key
        @c FIRAuthErrorUserInfoDecodedResponseKey.
 */
- (void)testErrorResponseWithNoErrorMessage {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  NSError *error = [NSError errorWithDomain:kFakeErrorDomain code:kFakeErrorCode userInfo:@{}];
  [_RPCIssuer respondWithJSON:@{} error:error];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeUnexpectedErrorResponse);

  NSError *underlyingUnderlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNil(underlyingUnderlyingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSDictionary class]]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testClientErrorResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response contains a client error specified by an error messsage sent from the backend.
 */
- (void)testClientErrorResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackerror;
  __block BOOL callBackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callBackInvoked = YES;
                               callbackerror = error;
                             }];
  NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
  NSString *customErrorMessage =
      [NSString stringWithFormat:@"%@%@%@", kUserDisabledErrorMessage, kServerErrorDetailMarker,
                                 kFakeUserDisabledCustomErrorMessage];
  [_RPCIssuer respondWithServerErrorMessage:customErrorMessage error:error];
  XCTAssertNotNil(callbackerror, @"An error should be returned from callback.");
  XCTAssert(callBackInvoked);
  XCTAssertEqual(callbackerror.code, FIRAuthErrorCodeUserDisabled);
  NSString *customMessage = callbackerror.userInfo[NSLocalizedDescriptionKey];
  XCTAssertEqualObjects(customMessage, kFakeUserDisabledCustomErrorMessage);
}

/** @fn testUndecodableSuccessResponse
    @brief This test checks the behaviour of @c postWithRequest:response:callback: when the
        response isn't decodable by the response class but no error condition was expected. We are
        expecting to receive an @c NSError with the code
        @c FIRAuthErrorCodeUnexpectedServerResponse and the error from @c setWithDictionary:error:
        as the value of the underlyingError.
 */
- (void)testUndecodableSuccessResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponseWithDecodingError];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  // It doesn't matter what we respond with here, as long as it's not an error response. The fake
  // response will deterministicly simulate a decoding error regardless of the response value it was
  // given.
  [_RPCIssuer respondWithJSON:@{}];

  XCTAssert(callbackInvoked);

  XCTAssertNotNil(callbackError);
  XCTAssertEqualObjects(callbackError.domain, FIRAuthErrorDomain);
  XCTAssertEqual(callbackError.code, FIRAuthErrorCodeInternalError);

  NSError *underlyingError = callbackError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, FIRAuthInternalErrorDomain);
  XCTAssertEqual(underlyingError.code, FIRAuthInternalErrorCodeRPCResponseDecodingError);

  id deserializedResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDeserializedResponseKey];
  XCTAssertNotNil(deserializedResponse);
  XCTAssert([deserializedResponse isKindOfClass:[NSDictionary class]]);

  id dataResponse = underlyingError.userInfo[FIRAuthErrorUserInfoDataKey];
  XCTAssertNil(dataResponse);
}

/** @fn testSuccessfulResponse
    @brief Tests that a decoded dictionary is handed to the response instance.
 */
- (void)testSuccessfulResponse {
  FIRFakeRequest *request = [FIRFakeRequest fakeRequest];
  FIRFakeResponse *response = [FIRFakeResponse fakeResponse];

  __block NSError *callbackError;
  __block BOOL callbackInvoked;
  [_RPCImplementation postWithRequest:request
                             response:response
                             callback:^(NSError *error) {
                               callbackInvoked = YES;
                               callbackError = error;
                             }];

  [_RPCIssuer respondWithJSON:@{kTestKey : kTestValue}];

  XCTAssert(callbackInvoked);
  XCTAssertNil(callbackError);
  XCTAssertNotNil(response.receivedDictionary);
  XCTAssertEqualObjects(response.receivedDictionary[kTestKey], kTestValue);
}

@end
