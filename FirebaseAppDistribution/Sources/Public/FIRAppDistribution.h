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

#import <AppAuth/AppAuth.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FIRAppDistributionRelease.h"

NS_ASSUME_NONNULL_BEGIN

/**
 *  @related AppDistributionError
 *
 *  The completion handler invoked when the new build request returns.
 *  If the call fails we return the appropriate `error code`, described by
 *  `AppDistributionError`.
 *
 *  @param release  The new release that is available to be installed.
 *  @param error     The error describing why the new build request failed.
 */
typedef void (^FIRAppDistributionUpdateCheckCompletion)(
    FIRAppDistributionRelease *_Nullable release, NSError *_Nullable error)
    NS_SWIFT_NAME(AppDistributionUpdateCheckCompletion);

/**
 *  @related AppDistributionError
 *
 *  The completion handler invoked  when App Distribution sign in is complete
 *  If the call fails we return the appropriate `error code`, described by
 *  `AppDistributionError`.
 *
 *  @param error     The error describing why sign in failed
 */
typedef void (^FIRAppDistributionSignInTesterCompletion)(NSError *_Nullable error)
    NS_SWIFT_NAME(AppDistributionSignInTesterCompletion);

/**
 * The Firebase App Distribution API provides methods to check for update to
 * the app and returns information that enables updating the app.
 *
 * By default, Firebase App Distribution is initialized with `FirebaseApp.configure()`.
 *
 * Note: The App Distribution class cannot be subclassed. If this makes testing difficult,
 * we suggest using a wrapper class or a protocol extension.
 */
NS_SWIFT_NAME(AppDistribution)
@interface FIRAppDistribution : NSObject

// Is true if the App Distribution tester is signed in
@property(nonatomic, readonly) BOOL isTesterSignedIn;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

/**
 * Sign-in the App Distribution tester
 */
- (void)signInTesterWithCompletion:(FIRAppDistributionSignInTesterCompletion)completion
    NS_SWIFT_NAME(signInTester(completion:));

/**
 * Check to see whether a new distribution is available
 */
- (void)checkForUpdateWithCompletion:(FIRAppDistributionUpdateCheckCompletion)completion
    NS_SWIFT_NAME(checkForUpdate(completion:));

/**
 * Sign out App Distribution tester
 */
- (void)signOutTester;
/**
 * Accesses the singleton App Distribution instance.
 *
 * @return The singleton App Distribution instance.
 */
+ (instancetype)appDistribution NS_SWIFT_NAME(appDistribution());

@end

/**
 *  @enum AppDistributionError
 */
typedef NS_ENUM(NSUInteger, FIRAppDistributionError) {
  /// Unknown error.
  FIRAppDistributionErrorUnknown = 0,

  // Authentication failed
  FIRAppDistributionErrorAuthenticationFailure = 1,

  // Authentication canceled
  FIRAppDistributionErrorAuthenticationCancelled = 2,

  // Network unavailable to make requests or the request timed out
  FIRAppDistributionErrorNetworkFailure = 3,

} NS_SWIFT_NAME(AppDistributionError);

NS_ASSUME_NONNULL_END
