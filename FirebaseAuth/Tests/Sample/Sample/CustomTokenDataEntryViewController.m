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

#import "CustomTokenDataEntryViewController.h"

/** @var navigationBarDefaultHeight
    @brief The default height to use for new navigation bars' frames.
 */
static const NSUInteger navigationBarDefaultHeight = 55;

/** @var navigationBarSystemHeight
    @brief Set after a navigation bar has been created to obtain the system-specified height of the
        navigation bar.
 */
static NSUInteger navigationBarSystemHeight = navigationBarDefaultHeight;

/** @var kTitle
    @brief The title of the view controller as it appears at the top of the screen in the navigation
        bar.
 */
static NSString *const kTitle = @"Enter Token";

/** @var kCancel
    @brief The text for the "Cancel" button.
 */
static NSString *const kCancel = @"Cancel";

/** @var kDone
    @brief The text for the "Done" button.
 */
static NSString *const kDone = @"Done";

@implementation CustomTokenDataEntryViewController {
  /** @var _completion
      @brief The block we will call when the user presses the "cancel" or "done" buttons.
      @remarks Passed into the initializer.
   */
  CustomTokenDataEntryViewControllerCompletion _completion;

  /** @var _tokenTextView
      @brief The text view allowing the user to enter their custom token text.
      @remarks Constructed and set in the method: @c loadTextView.
   */
  __weak UITextView *_Nullable _tokenTextView;
}

- (nullable instancetype)initWithCompletion:
    (CustomTokenDataEntryViewControllerCompletion)completion {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _completion = completion;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  [self loadHeader];
  [self loadTextView];
}

#pragma mark - View

/** @fn loadHeader
    @brief Loads the header bar along the top of the view with "Cancel" and "Done" buttons, as well
        as a brief title asking the user to enter the custom token text.
    @remarks Updates navigationBarSystemHeight, so should be called before any method which depends
        on that variable being updated (like the @c loadTextView method, which uses the value to
        determine how much room is left on the screen.)
 */
- (void)loadHeader {
  CGRect navBarFrame = CGRectMake(0, 0, self.view.bounds.size.width, navigationBarDefaultHeight);
  UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
  navBar.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin;

  UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:kTitle];
  UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:kCancel
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(cancelPressed:)];
  UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:kDone
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(donePressed:)];
  navItem.leftBarButtonItem = cancelButton;
  navItem.rightBarButtonItem = doneButton;

  [navBar setItems:@[ navItem ] animated:NO];

  [self.view addSubview:navBar];

  // Obtain the system-specified height of the navigation bar.
  navigationBarSystemHeight = navBar.frame.size.height;
}

/** @fn loadTextView
    @brief Loads the text field for the user to enter their custom token text.
    @remarks Relies on the navigationBarSystemHeight variable being correct.
 */
- (void)loadTextView {
  CGRect tokenTextViewFrame = CGRectMake(0, navigationBarSystemHeight, self.view.bounds.size.width,
                                         self.view.bounds.size.height - navigationBarSystemHeight);
  UITextView *tokenTextView = [[UITextView alloc] initWithFrame:tokenTextViewFrame];
  tokenTextView.backgroundColor = [UIColor whiteColor];
  tokenTextView.textAlignment = NSTextAlignmentLeft;

  [self.view addSubview:tokenTextView];
  _tokenTextView = tokenTextView;
}

#pragma mark - Actions

- (void)cancelPressed:(id)sender {
  [self finishByCancelling:YES withUserEnteredTokenText:nil];
}

- (void)donePressed:(id)sender {
  [self finishByCancelling:NO withUserEnteredTokenText:_tokenTextView.text];
}

#pragma mark - Workflow

- (void)finishByCancelling:(BOOL)cancelled
    withUserEnteredTokenText:(nullable NSString *)userEnteredTokenText {
  [self dismissViewControllerAnimated:YES
                           completion:^{
                             self->_completion(cancelled, cancelled ? nil : userEnteredTokenText);
                           }];
}

@end
