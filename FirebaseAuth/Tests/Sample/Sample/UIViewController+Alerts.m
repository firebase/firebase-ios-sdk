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

#import "UIViewController+Alerts.h"

#import <objc/runtime.h>

/*! @var kPleaseWaitAssociatedObjectKey
    @brief Key used to identify the "please wait" spinner associated object.
 */
static NSString *const kPleaseWaitAssociatedObjectKey =
    @"_UIViewControllerAlertCategory_PleaseWaitScreenAssociatedObject";

/*! @var kUseStatusBarSpinnerAssociatedObjectKey
    @brief The address of this constant is the key used to identify the "use status bar spinner"
        associated object.
 */
static const void *const kUseStatusBarSpinnerAssociatedObjectKey;

/*! @var kOK
    @brief Text for an 'OK' button.
 */
static NSString *const kOK = @"OK";

/*! @var kCancel
    @brief Text for an 'Cancel' button.
 */
static NSString *const kCancel = @"Cancel";

/*! @class SimpleTextPromptDelegate
    @brief A @c UIAlertViewDelegate which allows @c UIAlertView to be used with blocks more easily.
 */
@interface SimpleTextPromptDelegate : NSObject <UIAlertViewDelegate>

/*! @fn init
    @brief Please use initWithCompletionHandler.
 */
- (nullable instancetype)init NS_UNAVAILABLE;

/*! @fn initWithCompletionHandler:
    @brief Designated initializer.
    @param completionHandler The block to call when the alert view is dismissed.
 */
- (nullable instancetype)initWithCompletionHandler:(AlertPromptCompletionBlock)completionHandler
    NS_DESIGNATED_INITIALIZER;

@end

@implementation UIViewController (Alerts)

- (void)setUseStatusBarSpinner:(BOOL)useStatusBarSpinner {
  objc_setAssociatedObject(self, &kUseStatusBarSpinnerAssociatedObjectKey,
                           useStatusBarSpinner ? @(YES) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)useStatusBarSpinner {
  return objc_getAssociatedObject(self, &kUseStatusBarSpinnerAssociatedObjectKey) ? YES : NO;
}

/*! @fn supportsAlertController
    @brief Determines if the current platform supports @c UIAlertController.
    @return YES if the current platform supports @c UIAlertController.
 */
- (BOOL)supportsAlertController {
  return NSClassFromString(@"UIAlertController") != nil;
}

- (void)showMessagePrompt:(NSString *)message {
  [self showMessagePromptWithTitle:nil message:message showCancelButton:NO completion:nil];
}

- (void)showMessagePromptWithTitle:(nullable NSString *)title
                           message:(NSString *)message
                  showCancelButton:(BOOL)showCancelButton
                        completion:(nullable AlertPromptCompletionBlock)completion {
  if (message) {
    [UIPasteboard generalPasteboard].string = message;
  }
  if ([self supportsAlertController]) {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:kOK
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction *_Nonnull action) {
                                                       if (completion) {
                                                         completion(YES, nil);
                                                       }
                                                     }];
    [alert addAction:okAction];

    if (showCancelButton) {
      UIAlertAction *cancelAction =
          [UIAlertAction actionWithTitle:kCancel
                                   style:UIAlertActionStyleCancel
                                 handler:^(UIAlertAction *_Nonnull action) {
                                   completion(NO, nil);
                                 }];
      [alert addAction:cancelAction];
    }
    [self presentViewController:alert animated:YES completion:nil];
  } else {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
  }
}

- (void)showTextInputPromptWithMessage:(NSString *)message
                       completionBlock:(AlertPromptCompletionBlock)completion {
  [self showTextInputPromptWithMessage:message
                          keyboardType:UIKeyboardTypeDefault
                       completionBlock:completion];
}

- (void)showTextInputPromptWithMessage:(NSString *)message
                          keyboardType:(UIKeyboardType)keyboardType
                       completionBlock:(nonnull AlertPromptCompletionBlock)completion {
  if ([self supportsAlertController]) {
    UIAlertController *prompt =
        [UIAlertController alertControllerWithTitle:nil
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    __weak UIAlertController *weakPrompt = prompt;
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:kCancel
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *_Nonnull action) {
                                                           completion(NO, nil);
                                                         }];
    UIAlertAction *okAction =
        [UIAlertAction actionWithTitle:kOK
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *_Nonnull action) {
                                 UIAlertController *strongPrompt = weakPrompt;
                                 completion(YES, strongPrompt.textFields[0].text);
                               }];
    [prompt addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
      textField.keyboardType = keyboardType;
    }];
    [prompt addAction:cancelAction];
    [prompt addAction:okAction];
    [self presentViewController:prompt animated:YES completion:nil];
  } else {
    SimpleTextPromptDelegate *prompt =
        [[SimpleTextPromptDelegate alloc] initWithCompletionHandler:completion];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:nil
                                                        message:message
                                                       delegate:prompt
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:@"Ok", nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
  }
}

- (void)showQRCodePromptWithTextInput:(NSString *)message
                         qrCodeString:(NSString *)qrCodeString
                      completionBlock:(AlertPromptCompletionBlock)completion {
  // Create the QR code image from the provided string
  NSData *qrCodeData = [qrCodeString dataUsingEncoding:NSUTF8StringEncoding];
  CIFilter *qrCodeFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
  [qrCodeFilter setValue:qrCodeData forKey:@"inputMessage"];
  CIImage *qrCodeImage = qrCodeFilter.outputImage;

  // Scale the QR code image to an appropriate size
  CGRect extent = qrCodeImage.extent;
  CGFloat scale = MIN(240.0 / CGRectGetWidth(extent), 240.0 / CGRectGetHeight(extent));
  CIImage *scaledImage =
      [qrCodeImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
  UIImage *qrCodeUIImage = [UIImage imageWithCIImage:scaledImage];

  // Create the alert controller to display the QR code and text input
  UIAlertController *prompt =
      [UIAlertController alertControllerWithTitle:nil
                                          message:@"\n\n\n\n\n\n\n\n\n\n"
                                   preferredStyle:UIAlertControllerStyleAlert];
  __weak UIAlertController *weakPrompt = prompt;
  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *_Nonnull action) {
                                                         completion(NO, nil);
                                                       }];
  UIAlertAction *okAction =
      [UIAlertAction actionWithTitle:@"OK"
                               style:UIAlertActionStyleDefault
                             handler:^(UIAlertAction *_Nonnull action) {
                               UIAlertController *strongPrompt = weakPrompt;
                               completion(YES, strongPrompt.textFields[0].text);
                             }];
  [prompt addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
    textField.placeholder = @"Enter OTP";
  }];
  [prompt addAction:cancelAction];
  [prompt addAction:okAction];

  // Add the QR code image view to the alert controller
  UIImageView *qrCodeImageView = [[UIImageView alloc] initWithImage:qrCodeUIImage];
  qrCodeImageView.contentMode = UIViewContentModeScaleAspectFit;
  qrCodeImageView.translatesAutoresizingMaskIntoConstraints = NO;
  [prompt.view addSubview:qrCodeImageView];
  [qrCodeImageView.centerXAnchor constraintEqualToAnchor:prompt.view.centerXAnchor].active = YES;
  [qrCodeImageView.topAnchor constraintEqualToAnchor:prompt.view.topAnchor constant:10.0].active =
      YES;
  [qrCodeImageView.widthAnchor constraintEqualToConstant:240.0].active = YES;
  [qrCodeImageView.heightAnchor constraintEqualToConstant:240.0].active = YES;

  // Add the message label to the alert controller
  UILabel *messageLabel = [[UILabel alloc] init];
  messageLabel.text = message;
  messageLabel.textAlignment = NSTextAlignmentCenter;
  messageLabel.numberOfLines = 0;
  messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [prompt.view addSubview:messageLabel];
  [messageLabel.topAnchor constraintEqualToAnchor:qrCodeImageView.bottomAnchor constant:10.0]
      .active = YES;
  [messageLabel.leadingAnchor constraintEqualToAnchor:prompt.view.leadingAnchor constant:10.0]
      .active = YES;
  [messageLabel.trailingAnchor constraintEqualToAnchor:prompt.view.trailingAnchor constant:-10.0]
      .active = YES;

  // Present the alert controller
  [self presentViewController:prompt animated:YES completion:nil];
}

- (void)showSpinner:(nullable void (^)(void))completion {
  if (self.useStatusBarSpinner) {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    completion();
    return;
  }
  if ([self supportsAlertController]) {
    [self showModernSpinner:completion];
  } else {
    [self showIOS7Spinner:completion];
  }
}

- (void)showModernSpinner:(nullable void (^)(void))completion {
  UIAlertController *pleaseWaitAlert =
      objc_getAssociatedObject(self, (__bridge const void *)kPleaseWaitAssociatedObjectKey);
  if (pleaseWaitAlert) {
    if (completion) {
      completion();
    }
    return;
  }
  pleaseWaitAlert = [UIAlertController alertControllerWithTitle:nil
                                                        message:@"Please Wait...\n\n\n\n"
                                                 preferredStyle:UIAlertControllerStyleAlert];

  UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
  spinner.color = [UIColor blackColor];
  spinner.center = CGPointMake(pleaseWaitAlert.view.bounds.size.width / 2,
                               pleaseWaitAlert.view.bounds.size.height / 2);
  spinner.autoresizingMask =
      UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleTopMargin |
      UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
  [spinner startAnimating];
  [pleaseWaitAlert.view addSubview:spinner];

  objc_setAssociatedObject(self, (__bridge const void *)(kPleaseWaitAssociatedObjectKey),
                           pleaseWaitAlert, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [self presentViewController:pleaseWaitAlert animated:YES completion:completion];
}

- (void)showIOS7Spinner:(nullable void (^)(void))completion {
  UIWindow *pleaseWaitWindow =
      objc_getAssociatedObject(self, (__bridge const void *)kPleaseWaitAssociatedObjectKey);

  if (pleaseWaitWindow) {
    if (completion) {
      completion();
    }
    return;
  }

  pleaseWaitWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  pleaseWaitWindow.backgroundColor = [UIColor clearColor];
  pleaseWaitWindow.windowLevel = UIWindowLevelStatusBar - 1;

  UIView *pleaseWaitView = [[UIView alloc] initWithFrame:pleaseWaitWindow.bounds];
  pleaseWaitView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  pleaseWaitView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
  UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
  spinner.center = pleaseWaitView.center;
  [pleaseWaitView addSubview:spinner];
  [spinner startAnimating];

  pleaseWaitView.layer.opacity = 0.0;
  [self.view addSubview:pleaseWaitView];

  [pleaseWaitWindow addSubview:pleaseWaitView];

  [pleaseWaitWindow makeKeyAndVisible];

  objc_setAssociatedObject(self, (__bridge const void *)(kPleaseWaitAssociatedObjectKey),
                           pleaseWaitWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  [UIView animateWithDuration:0.5f
      animations:^{
        pleaseWaitView.layer.opacity = 1.0f;
      }
      completion:^(BOOL finished) {
        if (completion) {
          completion();
        }
      }];
}

- (void)hideSpinner:(nullable void (^)(void))completion {
  if (self.useStatusBarSpinner) {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    completion();
    return;
  }
  if ([self supportsAlertController]) {
    [self hideModernSpinner:completion];
  } else {
    [self hideIOS7Spinner:completion];
  }
}

- (void)hideModernSpinner:(nullable void (^)(void))completion {
  UIAlertController *pleaseWaitAlert =
      objc_getAssociatedObject(self, (__bridge const void *)kPleaseWaitAssociatedObjectKey);

  [pleaseWaitAlert dismissViewControllerAnimated:YES completion:completion];

  objc_setAssociatedObject(self, (__bridge const void *)(kPleaseWaitAssociatedObjectKey), nil,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)hideIOS7Spinner:(nullable void (^)(void))completion {
  UIWindow *pleaseWaitWindow =
      objc_getAssociatedObject(self, (__bridge const void *)kPleaseWaitAssociatedObjectKey);

  UIView *pleaseWaitView;
  pleaseWaitView = pleaseWaitWindow.subviews.firstObject;

  [UIView animateWithDuration:0.5f
      animations:^{
        pleaseWaitView.layer.opacity = 0.0f;
      }
      completion:^(BOOL finished) {
        [pleaseWaitWindow resignKeyWindow];
        objc_setAssociatedObject(self, (__bridge const void *)(kPleaseWaitAssociatedObjectKey), nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (completion) {
          completion();
        }
      }];
}

@end

@implementation SimpleTextPromptDelegate {
  AlertPromptCompletionBlock _completionHandler;
  SimpleTextPromptDelegate *_retainedSelf;
}

- (instancetype)initWithCompletionHandler:(AlertPromptCompletionBlock)completionHandler {
  self = [super init];
  if (self) {
    _completionHandler = completionHandler;
    _retainedSelf = self;
  }
  return self;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
  if (buttonIndex == alertView.firstOtherButtonIndex) {
    _completionHandler(YES, [alertView textFieldAtIndex:0].text);
  } else {
    _completionHandler(NO, nil);
  }
  _completionHandler = nil;
  _retainedSelf = nil;
}

@end
