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
#import <Foundation/Foundation.h>

#import "FirebaseAppDistribution/Sources/Private/FIRAppDistributionRelease.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @related FIRFADApiError
 *
 *  The completion handler invoked when the list releases request returns.
 *  If the call fails we return the appropriate `error code`, described by
 *  `AppDistributionApiError`.
 *
 *  @param releases  The releases that are available to be installed.
 *  @param error     The error describing why the new build request failed.
 */
typedef void (^FIRFADFetchReleasesCompletion)(NSArray *_Nullable releases, NSError *_Nullable error)
    NS_SWIFT_NAME(AppDistributionFetchReleasesCompletion);

/**
 *  @related FIRFADApiError
 *
 *  The completion handler invoked when the list releases request returns.
 *  If the call fails we return the appropriate `error code`, described by
 *  `AppDistributionApiError`.
 *
 *  @param identifier  The firebase installation identifier
 *  @param authTokenResult The installation auth token result.
 *  @param error     The error describing why the new build request failed.
 */
typedef void (^FIRFADGenerateAuthTokenCompletion)(
    NSString *_Nullable identifier,
    FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
    NSError *_Nullable error) NS_SWIFT_NAME(AppDistributionGenerateAuthTokenCompletion);

// Label exceptions from AppDistributionApi calls.
FOUNDATION_EXPORT NSString *const kFIRFADApiErrorDomain;

// A service encapsulating calls to the App Distribution Tester API
@interface FIRFADApiService : NSObject

// Fetch releases from the AppDistribution Tester API
+ (void)fetchReleasesWithCompletion:(FIRFADFetchReleasesCompletion)completion;

// Generate an installation auth token and fetch the installation id
+ (void)generateAuthTokenWithCompletion:(FIRFADGenerateAuthTokenCompletion)completion;

@end

/**
 *  @enum AppDistributionApiError
 */
typedef NS_ENUM(NSUInteger, FIRFADApiError) {
  // Timeout error.
  FIRFADApiErrorTimeout = 0,

  // Token generation error
  FIRFADApiTokenGenerationFailure = 1,

  // Installation Identifier not found error
  FIRFADApiInstallationIdentifierError = 2,

  // Authentication failed
  FIRFADApiErrorUnauthenticated = 3,

  // Authorization failed
  FIRFADApiErrorUnauthorized = 4,

  // Releases or tester not found
  FIRFADApiErrorNotFound = 5,

  // Api request failure for unknown reason
  FIRApiErrorUnknownFailure = 6,

  // Failure to parse Api response
  FIRApiErrorParseFailure = 7,

} NS_SWIFT_NAME(AppDistributionApiError);

NS_ASSUME_NONNULL_END
