/** @file UIViewController+Alerts.h
    @brief Firebase Auth SDK Sample App
    @copyright Copyright 2015 Google Inc.
    @remarks Use of this SDK is subject to the Google APIs Terms of Service:
        https://developers.google.com/terms/
 */

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/*! @typedef AlertPromptCompletionBlock
    @brief The type of callback used to report text input prompt results.
 */
typedef void (^AlertPromptCompletionBlock)(BOOL userPressedOK, NSString *_Nullable userInput);

/*! @class Alerts
    @brief Wrapper for @c UIAlertController and @c UIAlertView for backwards compatability with
        iOS 6+.
 */
@interface UIViewController (Alerts)

/*! @property useStatusBarSpinner
    @brief Uses the status bar to indicate work is occuring instead of a modal "please wait" dialog.
        This is generally useful for allowing user interaction while things are happening.
 */
@property(nonatomic, assign) BOOL useStatusBarSpinner;

/*! @fn showMessagePrompt:
    @brief Displays an alert with an 'OK' button and a message.
    @param message The message to display.
    @remarks The message is also copied to the pasteboard.
 */
- (void)showMessagePrompt:(NSString *)message;

/*! @fn showMessagePromptWithTitle:message:
    @brief Displays a titled alert with an 'OK' button and a message.
    @param title The title of the alert if it exists.
    @param message The message to display.
    @param showCancelButton A flag indicating whether or not a cancel option is available.
    @param completion The completion block to be executed after the alert is dismissed, if it
        exists.
    @remarks The message is also copied to the pasteboard.
 */
- (void)showMessagePromptWithTitle:(nullable NSString *)title
                           message:(NSString *)message
                  showCancelButton:(BOOL)showCancelButton
                        completion:(nullable AlertPromptCompletionBlock)completion;

/*! @fn showTextInputPromptWithMessage:completionBlock:
    @brief Shows a prompt with a text field and 'OK'/'Cancel' buttons.
    @param message The message to display.
    @param completion A block to call when the user taps 'OK' or 'Cancel'.
 */
- (void)showTextInputPromptWithMessage:(NSString *)message
                       completionBlock:(AlertPromptCompletionBlock)completion;

/*! @fn showSpinner
    @brief Shows the please wait spinner.
    @param completion Called after the spinner has been hidden.
 */
- (void)showSpinner:(nullable void(^)(void))completion;

/*! @fn hideSpinner
    @brief Hides the please wait spinner.
    @param completion Called after the spinner has been hidden.
 */
- (void)hideSpinner:(nullable void(^)(void))completion;

@end

NS_ASSUME_NONNULL_END
