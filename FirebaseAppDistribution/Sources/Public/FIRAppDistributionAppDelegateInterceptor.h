// Copyright 2019 Google
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

@protocol OIDExternalUserAgentSession;

/// An instance of this class is meant to be registered as an AppDelegate interceptor, and
/// implements the logic that my SDK needs to perform when certain app delegate methods are invoked.
@interface FIRAppDistributionAppDelegatorInterceptor : NSObject <UIApplicationDelegate>

/// Returns the MYAppDelegateInterceptor singleton.
/// Always register just this singleton as the app delegate interceptor. This instance is
/// retained. The App Delegate Swizzler only retains weak references and so this is needed.
+ (instancetype)sharedInstance;

/*! @brief The authorization flow session which receives the return URL from
   \SFSafariViewController.
    @discussion We need to store this in the app delegate as it's that delegate which receives the
        incoming URL on UIApplicationDelegate.application:openURL:options:. This property will be
        nil, except when an authorization flow is in progress.
 */
@property(nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;

@end

NS_ASSUME_NONNULL_END
