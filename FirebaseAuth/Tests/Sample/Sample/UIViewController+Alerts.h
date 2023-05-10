/*
 * Copyright 2019 Google
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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/*! @typedef AlertPromptCompletionBlock
    @brief The type of callback used to report text input prompt results.
 */
typedef void (^AlertPromptCompletionBlock)(BOOL userPressedOK, NSString *_Nullable userInput);

/*! @category UIViewController(Alerts)
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

/*! @fn showTextInputPromptWithMessage:keyboardType:completionBlock:
    @brief Shows a prompt with a text field and 'OK'/'Cancel' buttons.
    @param message The message to display.
    @param keyboardType The type of keyboard to display for the UITextView in the prompt.
    @param completion A block to call when the user taps 'OK' or 'Cancel'.
 */
- (void)showTextInputPromptWithMessage:(NSString *)message
                          keyboardType:(UIKeyboardType)keyboardType
                       completionBlock:(AlertPromptCompletionBlock)completion;

/*! @fn showTextInputPromptWithMessage:completionBlock:
    @brief Shows a prompt with a text field and 'OK'/'Cancel' buttons.
    @param message The message to display.
    @param completion A block to call when the user taps 'OK' or 'Cancel'.
 */
- (void)showTextInputPromptWithMessage:(NSString *)message
                       completionBlock:(AlertPromptCompletionBlock)completion;

/*! @fn showQRCodePromptWithTextInput:message:qrCodeString:completionBlock:
		@brief Shows a prompt with a QR code image, text message, text field for input, and 'OK'/'Cancel' buttons.
		@param message The message to display.
		@param qrCodeString The string to encode as a QR code and display as an image.
		@param completion A block to call when the user taps 'OK' or 'Cancel'.
 */
- (void)showQRCodePromptWithTextInput:(NSString *)message
													qrCodeString:(NSString *)qrCodeString
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
