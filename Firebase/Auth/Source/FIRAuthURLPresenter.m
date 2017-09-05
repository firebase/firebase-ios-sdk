/*
 * Copyright 2017 Google
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

#import "FIRAuthURLPresenter.h"

#import "FIRAuthErrorUtils.h"
#import "FIRAuthUIDelegate.h"

@import SafariServices;

NS_ASSUME_NONNULL_BEGIN

@interface FIRAuthDefaultUIDelegate : NSObject <FIRAuthUIDelegate>
/** @fn defaultUIDelegate
    @brief Returns a default FIRAuthUIDelegate object.
    @return The default FIRAuthUIDelegate object.
 */
+ (id<FIRAuthUIDelegate>)defaultUIDelegate;
@end

@interface FIRAuthURLPresenter () <SFSafariViewControllerDelegate>
@end

@implementation FIRAuthURLPresenter {
  /** @var _callbackMatcher
      @brief The callback URL matcher for the current presentation, if one is active.
   */
  FIRAuthURLCallbackMatcher _Nullable _callbackMatcher;

  /** @var _safariViewController
      @brief The SFSafariViewController used for the current presentation, if any.
   */
  SFSafariViewController *_Nullable _safariViewController;

  /** @var _UIDelegate
      @brief The UIDelegate used to present the SFSafariViewController.
   */
  id<FIRAuthUIDelegate> _UIDelegate;

  /** @var _completion
      @brief The completion handler for the current presentaion, if one is active.
      @remarks This variable is also used as a flag to indicate a presentation is active.
   */
  FIRAuthURLPresentationCompletion _Nullable _completion;
}

- (void)presentURL:(NSURL *)URL
        UIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
   callbackMatcher:(FIRAuthURLCallbackMatcher)callbackMatcher
        completion:(FIRAuthURLPresentationCompletion)completion {
  _callbackMatcher = callbackMatcher;
  _completion = completion;
  _UIDelegate = UIDelegate ?: [FIRAuthDefaultUIDelegate defaultUIDelegate];
  [self presentWebContextWithController:_UIDelegate URL:URL];
}

- (BOOL)canHandleURL:(NSURL *)URL {
  if (_callbackMatcher && _callbackMatcher(URL)) {
    _callbackMatcher = nil;
    [self finishPresentationWithURL:URL error:nil];
    return YES;
  }
  return NO;
}

/** @fn presentWebContextWithController:URL:
    @brief Presents a SFSafariViewController or WKWebView to display the contents of the URL
        provided.
    @param controller The controller used to present the SFSafariViewController or WKWebView.
    @param URL The URL to display in the SFSafariViewController or WKWebView.
 */
- (void)presentWebContextWithController:(id)controller URL:(NSURL *)URL {
  if ([SFSafariViewController class]) {
    if (_safariViewController) {
      // Unable to start a new presentation on top of modal SFSVC presentation.
      _completion(nil, [FIRAuthErrorUtils webContextAlreadyPresentedErrorWithMessage:nil]);
      return;
    }
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:URL];
    _safariViewController = safariViewController;
    _safariViewController.delegate = self;
    [controller presentViewController:safariViewController animated:YES completion:nil];
    return;
  }
}

#pragma mark - SFSafariViewControllerDelegate

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller {
  if (controller == _safariViewController) {
    _safariViewController = nil;
    //TODO:Ensure that the SFSafariViewController is actually removed from the screen before
    //invoking finishPresentationWithURL:error:
    [self finishPresentationWithURL:nil
                              error:[FIRAuthErrorUtils webContextCancelledErrorWithMessage:nil]];
  }
}

#pragma mark - Private methods

/** @fn finishPresentationWithURL:error:
    @brief Finishes the presentation for a given URL, if any.
    @param URL The URL to finish presenting.
    @param error The error with which to finish presenting, if any.
 */
- (void)finishPresentationWithURL:(nullable NSURL *)URL
                            error:(nullable NSError *)error {
  FIRAuthURLPresentationCompletion completion = _completion;
  void (^finishBlock)() = ^() {
    completion(URL, nil);
  };
  _completion = nil;
  if ([SFSafariViewController class]) {
    SFSafariViewController *safariViewController = _safariViewController;
    _safariViewController = nil;
    if (safariViewController) {
      [_UIDelegate dismissViewControllerAnimated:YES completion:finishBlock];
    }
  }
}

@end

NS_ASSUME_NONNULL_END
