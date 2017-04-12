/** @file ApplicationDelegate.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol OpenURLDelegate <NSObject>

/** @fn handleOpenURL:sourceApplication:
    @brief Handles application:openURL:... methods for @c UIApplicationDelegate .
 */
- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(nullable NSString *)sourceApplication;

@end

/** @class ApplicationDelegate
    @brief The sample application's delegate.
 */
@interface ApplicationDelegate : UIResponder <UIApplicationDelegate>

/** @property window
    @brief The sample application's @c UIWindow.
 */
@property(strong, nonatomic) UIWindow *window;

/** @fn setOpenURLDelegate:
    @brief Sets the delegate to handle application:openURL:... methods.
    @param openURLDelegate The delegate which is not retained by this method.
 */
+ (void)setOpenURLDelegate:(nullable id<OpenURLDelegate>)openURLDelegate;

@end

NS_ASSUME_NONNULL_END
