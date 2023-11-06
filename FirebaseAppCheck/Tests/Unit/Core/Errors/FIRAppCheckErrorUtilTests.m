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

@interface FIRAppCheckErrorUtilTests : XCTestCase

@property(nonatomic) NSDictionary<NSErrorUserInfoKey, id> *userInfo;

@end

@implementation FIRAppCheckErrorUtilTests

- (void)setUp {
  self.userInfo = @{NSLocalizedFailureReasonErrorKey : @"Failure reason"};
}

- (void)testPublicDomainErrorForGACErrorUnknown {
  NSError *unknownError = [NSError errorWithDomain:GACAppCheckErrorDomain
                                              code:GACAppCheckErrorCodeUnknown
                                          userInfo:self.userInfo];

  NSError *publicUnknownError = [FIRAppCheckErrorUtil publicDomainErrorWithError:unknownError];

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

  XCTAssertEqualObjects(publicUnknownError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqual(publicUnknownError.code, FIRAppCheckErrorCodeUnknown);
  XCTAssertEqual(publicUnknownError.localizedFailureReason, unknownError.localizedFailureReason);

  NSError *underlyingError = publicUnknownError.userInfo[NSUnderlyingErrorKey];
  XCTAssertNotNil(underlyingError);
  XCTAssertEqualObjects(underlyingError.domain, GACAppCheckErrorDomain);
  XCTAssertEqual(underlyingError.code, unknownError.code);
  XCTAssertEqualObjects(underlyingError.userInfo, unknownError.userInfo);
  XCTAssertEqualObjects(underlyingError.userInfo, self.userInfo);
}

@end
