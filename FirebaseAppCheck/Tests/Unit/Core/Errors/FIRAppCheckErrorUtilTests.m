/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

#import <XCTest/XCTest.h>

#import <AppCheckCore/AppCheckCore.h>

static NSString *const kTestErrorDomain = @"com.google.test.error-domain";
static NSInteger kTestErrorCode = 42;

@interface FIRAppCheckErrorUtilTests : XCTestCase

@property(nonatomic) NSError *underlyingError;
@property(nonatomic) NSDictionary<NSErrorUserInfoKey, id> *userInfo;

@end

@implementation FIRAppCheckErrorUtilTests

- (void)setUp {
  self.underlyingError = [NSError errorWithDomain:kTestErrorDomain
                                             code:kTestErrorCode
                                         userInfo:nil];
  self.userInfo = @{
    NSUnderlyingErrorKey : self.underlyingError,
    NSLocalizedFailureReasonErrorKey : @"Sample Failure Reason"
  };
}

- (void)testPublicDomainErrorForPublicError {
  NSError *expectedError = [NSError errorWithDomain:FIRAppCheckErrorDomain
                                               code:FIRAppCheckErrorCodeServerUnreachable
                                           userInfo:self.userInfo];

  NSError *publicError = [FIRAppCheckErrorUtil publicDomainErrorWithError:expectedError];

  XCTAssertNotNil(publicError);
  XCTAssertEqualObjects(expectedError, publicError);
}

- (void)testPublicDomainErrorForGACErrorUnknown {
  NSError *unknownError = [NSError errorWithDomain:GACAppCheckErrorDomain
                                              code:GACAppCheckErrorCodeUnknown
                                          userInfo:self.userInfo];

  NSError *publicUnknownError = [FIRAppCheckErrorUtil publicDomainErrorWithError:unknownError];

  XCTAssertNotNil(publicUnknownError);
  XCTAssertEqualObjects(publicUnknownError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicUnknownError.code, FIRAppCheckErrorCodeUnknown);
  XCTAssertEqualObjects(unknownError.userInfo, self.userInfo);
  XCTAssertEqualObjects(publicUnknownError.userInfo, unknownError.userInfo);
}

- (void)testPublicDomainErrorForGACErrorServerUnreachable {
  NSError *serverError = [NSError errorWithDomain:GACAppCheckErrorDomain
                                             code:GACAppCheckErrorCodeServerUnreachable
                                         userInfo:self.userInfo];

  NSError *publicServerError = [FIRAppCheckErrorUtil publicDomainErrorWithError:serverError];

  XCTAssertNotNil(publicServerError);
  XCTAssertEqualObjects(publicServerError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicServerError.code, FIRAppCheckErrorCodeServerUnreachable);
  XCTAssertEqualObjects(serverError.userInfo, self.userInfo);
  XCTAssertEqualObjects(publicServerError.userInfo, serverError.userInfo);
}

- (void)testPublicDomainErrorForGACErrorInvalidConfiguration {
  NSError *invalidConfigurationError =
      [NSError errorWithDomain:GACAppCheckErrorDomain
                          code:GACAppCheckErrorCodeInvalidConfiguration
                      userInfo:self.userInfo];

  NSError *publicInvalidConfigurationError =
      [FIRAppCheckErrorUtil publicDomainErrorWithError:invalidConfigurationError];

  XCTAssertNotNil(publicInvalidConfigurationError);
  XCTAssertEqualObjects(publicInvalidConfigurationError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicInvalidConfigurationError.code, FIRAppCheckErrorCodeInvalidConfiguration);
  XCTAssertEqualObjects(invalidConfigurationError.userInfo, self.userInfo);
  XCTAssertEqualObjects(publicInvalidConfigurationError.userInfo,
                        invalidConfigurationError.userInfo);
}

- (void)testPublicDomainErrorForGACErrorKeychain {
  NSError *keychainError = [NSError errorWithDomain:GACAppCheckErrorDomain
                                               code:GACAppCheckErrorCodeKeychain
                                           userInfo:self.userInfo];

  NSError *publicKeychainError = [FIRAppCheckErrorUtil publicDomainErrorWithError:keychainError];

  XCTAssertNotNil(publicKeychainError);
  XCTAssertEqualObjects(publicKeychainError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicKeychainError.code, FIRAppCheckErrorCodeKeychain);
  XCTAssertEqualObjects(keychainError.userInfo, self.userInfo);
  XCTAssertEqualObjects(publicKeychainError.userInfo, keychainError.userInfo);
}

- (void)testPublicDomainErrorForGACErrorUnsupported {
  NSError *unsupportedError = [NSError errorWithDomain:GACAppCheckErrorDomain
                                                  code:GACAppCheckErrorCodeUnsupported
                                              userInfo:self.userInfo];

  NSError *publicUnsupportedError =
      [FIRAppCheckErrorUtil publicDomainErrorWithError:unsupportedError];

  XCTAssertNotNil(publicUnsupportedError);
  XCTAssertEqualObjects(publicUnsupportedError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicUnsupportedError.code, FIRAppCheckErrorCodeUnsupported);
  XCTAssertEqualObjects(unsupportedError.userInfo, self.userInfo);
  XCTAssertEqualObjects(publicUnsupportedError.userInfo, unsupportedError.userInfo);
}

- (void)testPublicDomainErrorForGACErrorUnrecognizedCode {
  NSInteger unrecognizedErrorCode = -1000;  // Not part of the GACAppCheckErrorCode enum
  NSError *unknownError = [NSError errorWithDomain:GACAppCheckErrorDomain
                                              code:unrecognizedErrorCode
                                          userInfo:self.userInfo];

  NSError *publicUnknownError = [FIRAppCheckErrorUtil publicDomainErrorWithError:unknownError];

  XCTAssertNotNil(publicUnknownError);
  XCTAssertEqualObjects(publicUnknownError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicUnknownError.code, FIRAppCheckErrorCodeUnknown);
  XCTAssertEqual(publicUnknownError.localizedFailureReason, unknownError.localizedFailureReason);

  // Verify that the unrecognized error is wrapped as an underlying error.
  NSError *underlyingError = publicUnknownError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError, unknownError);
}

- (void)testPublicDomainErrorForUnrecognizedDomainError {
  // Error from an unrecognized domain (i.e., not FIRAppCheckErrorDomain or GACAppCheckErrorDomain).
  NSError *unrecognizedError = [NSError errorWithDomain:kTestErrorDomain
                                                   code:kTestErrorCode
                                               userInfo:self.userInfo];

  NSError *publicUnknownError = [FIRAppCheckErrorUtil publicDomainErrorWithError:unrecognizedError];

  XCTAssertNotNil(publicUnknownError);
  XCTAssertEqualObjects(publicUnknownError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicUnknownError.code, FIRAppCheckErrorCodeUnknown);
  XCTAssertEqual(publicUnknownError.localizedFailureReason,
                 unrecognizedError.localizedFailureReason);

  // Verify that the unrecognized error is wrapped as an underlying error.
  NSError *underlyingError = publicUnknownError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError, unrecognizedError);
}

@end
