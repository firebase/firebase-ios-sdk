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
