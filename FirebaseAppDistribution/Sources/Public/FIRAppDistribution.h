// Copyright 2020 Google
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
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
* The release information returned by the update check when a new version is available.
*/
NS_SWIFT_NAME(AppDistributionRelease)
@interface FIRAppDistributionRelease : NSObject

// The bundle version of this build (example: 123)
@property(nonatomic, copy) NSString *bundleVersion;
// The short bundle version of this build (example 1.0.0)
@property(nonatomic, copy) NSString *bundleShortVersion;
// The release notes for this build
@property(nonatomic, copy) NSString *releaseNotes;
// The URL for the build
@property(nonatomic, strong) NSURL *downloadUrl;

/** :nodoc: */
//- (instancetype)init NS_UNAVAILABLE;

@end

/**
 *  @related FIRAppDistribution
 *
 *  The completion handler invoked when the new build request returns.
 *  If the call fails we return the appropriate `error code`, described by
 *  `FIRAppDistributionError`.
 *
 *  @param release  The new release that is available to be installed.
 *  @param error     The error describing why the new build request failed.
 */
typedef void (^FIRAppDistributionUpdateCheckCompletion)(FIRAppDistributionRelease *_Nullable release,
                                                    NSError *_Nullable error)
    NS_SWIFT_NAME(AppDistributionNewBuildCheckCompletion);

/**
 * The Firebase App Distribution API provides methods to check for update to
 * the app and returns information that enables updating the app.
 *
 * By default, Firebase App Distribution is initialized with `[FIRApp configure]`.
 *
 * Note: The App Distribution class cannot be subclassed. If this makes testing difficult,
 * we suggest using a wrapper class or a protocol extension.
 */
NS_SWIFT_NAME(AppDistribution)
@interface FIRAppDistribution : NSObject

@property (nonatomic, readonly	) BOOL signedIn;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;
/**
 * Check to see whether a new distribution is available
 */
- (void)checkForUpdateWithView:(UIViewController *)view
                                completion:(FIRAppDistributionUpdateCheckCompletion)completion
    NS_SWIFT_NAME(checkForUpdate(view:completion:));

/**
 * Accesses the singleton App Distribution instance.
 *
 * @return The singleton App Distribution instance.
 */
+ (instancetype)appDistribution NS_SWIFT_NAME(appDistribution());

@end

/**
 *  @enum FIRAppDistributionError
 */
typedef NS_ENUM(NSUInteger, FIRAppDistributionError) {
  /// Unknown error.
  FIRAppDistributionErrorUnknown = 0,

} NS_SWIFT_NAME(AppDistributionError);

NS_ASSUME_NONNULL_END
