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

#import <objc/runtime.h>

#import "AppManager.h"
#import "AuthCredentials.h"
#import "FacebookAuthProvider.h"
#import <FirebaseAuth/FirebaseAuth.h>
#import "GoogleAuthProvider.h"
#import "MainViewController+App.h"
#import "MainViewController+Auth.h"
#import "MainViewController+AutoTests.h"
#import "MainViewController+Custom.h"
#import "MainViewController+Email.h"
#import "MainViewController+Facebook.h"
#import "MainViewController+GameCenter.h"
#import "MainViewController+Google.h"
#import "MainViewController+Internal.h"
#import "MainViewController+MultiFactor.h"
#import "MainViewController+OAuth.h"
#import "MainViewController+OOB.h"
#import "MainViewController+Phone.h"
#import "MainViewController+User.h"
#import "SettingsViewController.h"
#import "StaticContentTableViewManager.h"
#import "UIViewController+Alerts.h"
#import "UserInfoViewController.h"
#import "UserTableViewCell.h"
@import FirebaseAuth;;;

NS_ASSUME_NONNULL_BEGIN

static NSString *const kSectionTitleSettings = @"Settings";

static NSString *const kSectionTitleUserDetails = @"User Defaults";

static NSString *const kSwitchToInMemoryUserTitle = @"Switch to in memory user";

static NSString *const kNewOrExistingUserToggleTitle = @"New or Existing User Toggle";

extern NSString *const FIRAuthErrorUserInfoMultiFactorResolverKey;

typedef void (^FIRTokenCallback)(NSString *_Nullable token, NSError *_Nullable error);

@implementation MainViewController {
  NSMutableString *_consoleString;

  /** @var _userInMemory
      @brief Acts like the "memory" function of a calculator. An operation allows sample app users
          to assign this value based on @c FIRAuth.currentUser or clear this value.
   */
  FIRUser *_userInMemory;

  /** @var _useUserInMemory
      @brief Instructs the application to use _userInMemory instead of @c FIRAuth.currentUser for
          testing operations. This allows us to test if things still work with a user who is not
          the @c FIRAuth.currentUser, and also allows us to test those things while
          @c FIRAuth.currentUser remains nil (after a sign-out) and also when @c FIRAuth.currentUser
          is non-nil (do to a subsequent sign-in.)
   */
  BOOL _useUserInMemory;
}

- (id)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    _actionCodeRequestType = ActionCodeRequestTypeInApp;
    _actionCodeContinueURL = [NSURL URLWithString:KCONTINUE_URL];
    _authStateDidChangeListeners = [NSMutableArray array];
    _IDTokenDidChangeListeners = [NSMutableArray array];
    _googleOAuthProvider = [FIROAuthProvider providerWithProviderID:FIRGoogleAuthProvider.string];
    _microsoftOAuthProvider = [FIROAuthProvider providerWithProviderID:@"microsoft.com"];
    _twitterOAuthProvider = [FIROAuthProvider providerWithProviderID:@"twitter.com"];
    _linkedinOAuthProvider = [FIROAuthProvider providerWithProviderID:@"linkedin.com"];
    _yahooOAuthProvider = [FIROAuthProvider providerWithProviderID:@"yahoo.com"];
    _gitHubOAuthProvider = [FIROAuthProvider providerWithProviderID:@"github.com"];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(authStateChangedForAuth:)
                                                 name:FIRAuthStateDidChangeNotification
                                               object:nil];
    self.useStatusBarSpinner = YES;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Give us a circle for the image view:
  _userInfoTableViewCell.userInfoProfileURLImageView.layer.cornerRadius =
      _userInfoTableViewCell.userInfoProfileURLImageView.frame.size.width / 2.0f;
  _userInfoTableViewCell.userInfoProfileURLImageView.layer.masksToBounds = YES;
  _userInMemoryInfoTableViewCell.userInfoProfileURLImageView.layer.cornerRadius =
      _userInMemoryInfoTableViewCell.userInfoProfileURLImageView.frame.size.width / 2.0f;
  _userInMemoryInfoTableViewCell.userInfoProfileURLImageView.layer.masksToBounds = YES;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateTable];
  [self updateUserInfo];
}

#pragma mark - Public

- (BOOL)handleIncomingLinkWithURL:(NSURL *)URL {
  // Parse the query portion of the incoming URL.
  NSDictionary<NSString *, NSString *> *queryItems =
  parseURL([NSURLComponents componentsWithString:URL.absoluteString].query);

  // Check that all necessary query items are available.
  NSString *actionCode = queryItems[@"oobCode"];
  NSString *mode = queryItems[@"mode"];
  if (!actionCode || !mode) {
    return NO;
  }
  // Handle Password Reset action.
  if ([mode isEqualToString:kPasswordResetAction]) {
    [self showTextInputPromptWithMessage:@"New Password:"
                         completionBlock:^(BOOL userPressedOK, NSString *_Nullable newPassword) {
    if (!userPressedOK || !newPassword.length) {
     [UIPasteboard generalPasteboard].string = actionCode;
     return;
    }
    [self showSpinner:^() {
      [[AppManager auth] confirmPasswordResetWithCode:actionCode
                                         newPassword:newPassword
                                          completion:^(NSError *_Nullable error) {
          [self hideSpinner:^{
            if (error) {
              [self logFailure:@"Password reset in app failed" error:error];
              [self showMessagePrompt:error.localizedDescription];
              return;
            }
            [self logSuccess:@"Password reset in app succeeded."];
            [self showMessagePrompt:@"Password reset in app succeeded."];
          }];
        }];
      }];
    }];
    return YES;
  }
  if ([mode isEqualToString:kVerifyEmailAction]) {
    [self showMessagePromptWithTitle:@"Tap OK to verify email"
                             message:actionCode
                    showCancelButton:YES
                          completion:^(BOOL userPressedOK, NSString *_Nullable userInput) {
      if (!userPressedOK) {
        return;
      }
      [self showSpinner:^() {
        [[AppManager auth] applyActionCode:actionCode completion:^(NSError *_Nullable error) {
          [self hideSpinner:^{
            if (error) {
              [self logFailure:@"Verify email in app failed" error:error];
              [self showMessagePrompt:error.localizedDescription];
              return;
            }
            [self logSuccess:@"Verify email in app succeeded."];
            [self showMessagePrompt:@"Verify email in app succeeded."];
          }];
        }];
      }];
    }];
    return YES;
  }
  return NO;
}

static NSDictionary<NSString *, NSString *> *parseURL(NSString *urlString) {
  NSString *linkURL = [NSURLComponents componentsWithString:urlString].query;
  NSArray<NSString *> *URLComponents = [linkURL componentsSeparatedByString:@"&"];
  NSMutableDictionary<NSString *, NSString *> *queryItems =
  [[NSMutableDictionary alloc] initWithCapacity:URLComponents.count];
  for (NSString *component in URLComponents) {
    NSRange equalRange = [component rangeOfString:@"="];
    if (equalRange.location != NSNotFound) {
      NSString *queryItemKey =
      [[component substringToIndex:equalRange.location] stringByRemovingPercentEncoding];
      NSString *queryItemValue =
      [[component substringFromIndex:equalRange.location + 1] stringByRemovingPercentEncoding];
      if (queryItemKey && queryItemValue) {
        queryItems[queryItemKey] = queryItemValue;
      }
    }
  }
  return queryItems;
}

- (void)updateTable {
  __weak typeof(self) weakSelf = self;
  _tableViewManager.contents =
    [StaticContentTableViewContent contentWithSections:@[
      // User Defaults
      [StaticContentTableViewSection sectionWithTitle:kSectionTitleUserDetails cells:@[
        [StaticContentTableViewCell cellWithCustomCell:_userInfoTableViewCell action:^{
          [weakSelf presentUserInfo];
        }],
        [StaticContentTableViewCell cellWithCustomCell:_userToUseCell],
        [StaticContentTableViewCell cellWithCustomCell:_userInMemoryInfoTableViewCell action:^{
          [weakSelf presentUserInMemoryInfo];
        }],
      ]],
      // Settings
      [StaticContentTableViewSection sectionWithTitle:kSectionTitleSettings cells:@[
        [StaticContentTableViewCell cellWithTitle:kSectionTitleSettings
                                           action:^{ [weakSelf presentSettings]; }],
        [StaticContentTableViewCell cellWithTitle:kNewOrExistingUserToggleTitle
                                            value:_isNewUserToggleOn ? @"Enabled" : @"Disabled"
                                           action:^{
          self->_isNewUserToggleOn = !self->_isNewUserToggleOn;
                                             [self updateTable]; }],
        [StaticContentTableViewCell cellWithTitle:kSwitchToInMemoryUserTitle
                                           action:^{ [weakSelf updateToSavedUser]; }],
        ]],
      // Auth
      [weakSelf authSection],
      // User
      [weakSelf userSection],
      // Multi Factor
      [weakSelf multiFactorSection],
      // Email Auth
      [weakSelf emailAuthSection],
      // Phone Auth
      [weakSelf phoneAuthSection],
      // Google Auth
      [weakSelf googleAuthSection],
      // Facebook Auth
      [weakSelf facebookAuthSection],
      // OAuth
      [weakSelf oAuthSection],
      // Custom Auth
      [weakSelf customAuthSection],
      // Game Center Auth
      [weakSelf gameCenterAuthSection],
      // App
      [weakSelf appSection],
      // OOB
      [weakSelf oobSection],
      // Auto Tests
      [weakSelf autoTestsSection],
    ]];
}

#pragma mark - Internal

- (FIRUser *)user {
  return _useUserInMemory ? _userInMemory : [AppManager auth].currentUser;
}

- (void)signInWithProvider:(nonnull id<AuthProvider>)provider callback:(void(^)(void))callback {
  if (!provider) {
    [self logFailedTest:@"A valid auth provider was not provided to the signInWithProvider."];
    return;
  }
  [provider getAuthCredentialWithPresentingViewController:self
                                                 callback:^(FIRAuthCredential *credential,
                                                            NSError *error) {
    if (!credential) {
      [self logFailedTest:@"The test needs a valid credential to continue."];
      return;
    }
      [[AppManager auth] signInWithCredential:credential
                                  completion:^(FIRAuthDataResult *_Nullable result,
                                               NSError *_Nullable error) {
      if (error) {
        [self logFailure:@"sign-in with provider failed" error:error];
        [self logFailedTest:@"Sign-in should succeed"];
        return;
      } else {
        [self logSuccess:@"sign-in with provider succeeded."];
        callback();
      }
    }];
  }];
}

- (FIRActionCodeSettings *)actionCodeSettings {
  FIRActionCodeSettings *actionCodeSettings = [[FIRActionCodeSettings alloc] init];
  actionCodeSettings.URL = self.actionCodeContinueURL;
  actionCodeSettings.handleCodeInApp = self.actionCodeRequestType == ActionCodeRequestTypeInApp;
  return actionCodeSettings;
}

- (void)reauthenticate:(id<AuthProvider>)authProvider retrieveData:(BOOL)retrieveData {
  FIRUser *user = [self user];
  if (!user) {
    NSString *provider = @"Firebase";
    if ([authProvider isKindOfClass:[GoogleAuthProvider class]]) {
      provider = @"Google";
    } else if ([authProvider isKindOfClass:[FacebookAuthProvider class]]) {
      provider = @"Facebook";
    }
    NSString *title = @"Missing User";
    NSString *message =
        [NSString stringWithFormat:@"There is no signed-in %@ user.", provider];
    [self showMessagePromptWithTitle:title message:message showCancelButton:NO completion:nil];
    return;
  }
  [authProvider getAuthCredentialWithPresentingViewController:self
                                                     callback:^(FIRAuthCredential *credential,
                                                                NSError *error) {
    if (credential) {
      FIRAuthDataResultCallback completion = ^(FIRAuthDataResult *_Nullable authResult,
                                               NSError *_Nullable error) {
        if (error) {
          if (error.code == FIRAuthErrorCodeSecondFactorRequired) {
            FIRMultiFactorResolver *resolver = error.userInfo[FIRAuthErrorUserInfoMultiFactorResolverKey];
            NSMutableString *displayNameString = [NSMutableString string];
            for (FIRMultiFactorInfo *tmpFactorInfo in resolver.hints) {
              [displayNameString appendString:tmpFactorInfo.displayName];
              [displayNameString appendString:@" "];
            }
            [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Select factor to reauthenticate\n%@", displayNameString]
                                 completionBlock:^(BOOL userPressedOK, NSString *_Nullable displayName) {
                                   FIRPhoneMultiFactorInfo* selectedHint;
                                   for (FIRMultiFactorInfo *tmpFactorInfo in resolver.hints) {
                                     if ([displayName isEqualToString:tmpFactorInfo.displayName]) {
                                       selectedHint = (FIRPhoneMultiFactorInfo *)tmpFactorInfo;
                                     }
                                   }
                                   [FIRPhoneAuthProvider.provider
                                    verifyPhoneNumberWithMultiFactorInfo:selectedHint
                                    UIDelegate:nil
                                    multiFactorSession:resolver.session
                                    completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
                                                    if (error) {
                                                      [self logFailure:@"Multi factor start sign in failed." error:error];
                                                    } else {
                                                      [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Verification code for %@", selectedHint.displayName]
                                                                           completionBlock:^(BOOL userPressedOK, NSString *_Nullable verificationCode) {
                                                                             FIRPhoneAuthCredential *credential =
                                                                             [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                                                                                          verificationCode:verificationCode];
                                                                             FIRMultiFactorAssertion *assertion = [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];
                                                                             [resolver resolveSignInWithAssertion:assertion completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
                                                                               if (error) {
                                                                                 [self logFailure:@"Multi factor finalize sign in failed." error:error];
                                                                               } else {
                                                                                 [self logSuccess:@"Multi factor finalize sign in succeeded."];
                                                                               }
                                                                             }];
                                                                           }];
                                                    }
                                                  }];
                                 }];
          } else {
            [self logFailure:@"reauthenticate operation failed." error:error];
          }
        } else {
          [self logSuccess:@"reauthenticate operation succeeded."];
        }
        if (authResult.additionalUserInfo) {
          [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
        }
      };
      [user reauthenticateWithCredential:credential completion:completion];
    }
  }];
}

- (void)signinWithProvider:(id<AuthProvider>)authProvider retrieveData:(BOOL)retrieveData {
  FIRAuth *auth = [AppManager auth];
  if (!auth) {
    return;
  }
  [authProvider getAuthCredentialWithPresentingViewController:self
                                                     callback:^(FIRAuthCredential *credential,
                                                                NSError *error) {
    if (credential) {
      FIRAuthDataResultCallback completion = ^(FIRAuthDataResult *_Nullable authResult,
                                               NSError *_Nullable error) {
        if (error) {
          [self logFailure:@"sign-in with provider failed" error:error];
        } else {
          [self logSuccess:@"sign-in with provider succeeded."];
        }
        if (authResult.additionalUserInfo) {
          [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
          if (self->_isNewUserToggleOn) {
            NSString *newUserString = authResult.additionalUserInfo.isNewUser ?
                @"New user" : @"Existing user";
            [self showMessagePromptWithTitle:@"New or Existing"
                                     message:newUserString
                            showCancelButton:NO
                                  completion:nil];
          }
        }
        [self showTypicalUIForUserUpdateResultsWithTitle:@"Sign-In" error:error];
      };
      [auth signInWithCredential:credential completion:completion];
    }
  }];
}

- (void)linkWithAuthProvider:(id<AuthProvider>)authProvider retrieveData:(BOOL)retrieveData {
  FIRUser *user = [self user];
  if (!user) {
    return;
  }
  [authProvider getAuthCredentialWithPresentingViewController:self
                                                     callback:^(FIRAuthCredential *credential,
                                                                NSError *error) {
    if (credential) {
      FIRAuthDataResultCallback completion = ^(FIRAuthDataResult *_Nullable authResult,
                                               NSError *_Nullable error) {
        if (error) {
          if (error.code == FIRAuthErrorCodeSecondFactorRequired) {
            FIRMultiFactorResolver *resolver = error.userInfo[FIRAuthErrorUserInfoMultiFactorResolverKey];
            NSMutableString *displayNameString = [NSMutableString string];
            for (FIRMultiFactorInfo *tmpFactorInfo in resolver.hints) {
              [displayNameString appendString:tmpFactorInfo.displayName];
              [displayNameString appendString:@" "];
            }
            [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Select factor to link\n%@", displayNameString]
                                 completionBlock:^(BOOL userPressedOK, NSString *_Nullable displayName) {
                                   FIRPhoneMultiFactorInfo* selectedHint;
                                   for (FIRMultiFactorInfo *tmpFactorInfo in resolver.hints) {
                                     if ([displayName isEqualToString:tmpFactorInfo.displayName]) {
                                       selectedHint = (FIRPhoneMultiFactorInfo *)tmpFactorInfo;
                                     }
                                   }
                                   [FIRPhoneAuthProvider.provider
                                    verifyPhoneNumberWithMultiFactorInfo:selectedHint
                                    UIDelegate:nil
                                    multiFactorSession:resolver.session
                                    completion:^(NSString * _Nullable verificationID, NSError * _Nullable error) {
              if (error) {
                [self logFailure:@"Multi factor start sign in failed." error:error];
              } else {
                [self showTextInputPromptWithMessage:[NSString stringWithFormat:@"Verification code for %@", selectedHint.displayName]
                                     completionBlock:^(BOOL userPressedOK, NSString *_Nullable verificationCode) {
                 FIRPhoneAuthCredential *credential =
                 [[FIRPhoneAuthProvider provider] credentialWithVerificationID:verificationID
                                                              verificationCode:verificationCode];
                 FIRMultiFactorAssertion *assertion = [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];
                 [resolver resolveSignInWithAssertion:assertion completion:^(FIRAuthDataResult * _Nullable authResult, NSError * _Nullable error) {
                   if (error) {
                     [self logFailure:@"Multi factor finalize sign in failed." error:error];
                   } else {
                     [self logSuccess:@"Multi factor finalize sign in succeeded."];
                   }
                 }];
               }];
              }
            }];
           }];
          } else {
            [self logFailure:@"link auth provider failed" error:error];
          }
        } else {
          [self logSuccess:@"link auth provider succeeded."];
        }
        if (authResult.additionalUserInfo) {
          [self logSuccess:[self stringWithAdditionalUserInfo:authResult.additionalUserInfo]];
        }
      };
      [user linkWithCredential:credential completion:completion];
    }
  }];
}

- (void)unlinkFromProvider:(NSString *)provider
                completion:(nullable TestAutomationCallback)completion {
  [[self user] unlinkFromProvider:provider
                       completion:^(FIRUser *_Nullable user,
                                    NSError *_Nullable error) {
    if (error) {
      [self logFailure:@"unlink auth provider failed" error:error];
      if (completion) {
        completion(error);
      }
      return;
    }
    [self logSuccess:@"unlink auth provider succeeded."];
    if (completion) {
      completion(nil);
    }
    [self showTypicalUIForUserUpdateResultsWithTitle:@"Unlink from Provider" error:error];
  }];
}

- (void)updateToSavedUser {
  if(![AppManager auth].currentUser) {
    NSLog(@"You must be signed in to perform this action");
    return;
  }

  if (!_userInMemory) {
    [self showMessagePrompt:[NSString stringWithFormat:@"You need an in-memory user to perform this"
    "action, use the M+ button to save a user to memory.", nil]];
    return;
  }

  [[AppManager auth] updateCurrentUser:_userInMemory completion:^(NSError *_Nullable error) {
    if (error) {
      [self showMessagePrompt:
          [NSString stringWithFormat:@"An error Occurred: %@", error.localizedDescription]];
      return;
    }
  }];
}

#pragma mark - Private

- (void)presentSettings {
  SettingsViewController *settingsViewController = [[SettingsViewController alloc]
                                                    initWithNibName:NSStringFromClass([SettingsViewController class])
                                                    bundle:nil];
  [self showViewController:settingsViewController sender:self];
}

- (void)presentUserInfo {
  UserInfoViewController *userInfoViewController =
  [[UserInfoViewController alloc] initWithUser:[AppManager auth].currentUser];
  [self showViewController:userInfoViewController sender:self];
}

- (void)presentUserInMemoryInfo {
  UserInfoViewController *userInfoViewController =
  [[UserInfoViewController alloc] initWithUser:_userInMemory];
  [self showViewController:userInfoViewController sender:self];
}

- (NSString *)stringWithAdditionalUserInfo:(nullable FIRAdditionalUserInfo *)additionalUserInfo {
  if (!additionalUserInfo) {
    return @"(no additional user info)";
  }
  NSString *newUserString = additionalUserInfo.isNewUser ? @"new user" : @"existing user";
  return [NSString stringWithFormat:@"%@: %@", newUserString, additionalUserInfo.profile];
}

- (void)showTypicalUIForUserUpdateResultsWithTitle:(NSString *)resultsTitle
                                             error:(NSError * _Nullable)error {
  if (error) {
    NSString *message = [NSString stringWithFormat:@"%@ (%ld)\n%@",
                                                   error.domain,
                                                   (long)error.code,
                                                   error.localizedDescription];
    if (error.code == FIRAuthErrorCodeAccountExistsWithDifferentCredential) {
      NSString *errorEmail = error.userInfo[FIRAuthErrorUserInfoEmailKey];
      resultsTitle = [NSString stringWithFormat:@"Existing email : %@", errorEmail];
    }
    [self showMessagePromptWithTitle:resultsTitle
                             message:message
                    showCancelButton:NO
                          completion:nil];
    return;
  }
  [self updateUserInfo];
}

- (void)showUIForAuthDataResultWithResult:(FIRAuthDataResult *)result
                                    error:(NSError * _Nullable)error {
  NSString *errorMessage = [NSString stringWithFormat:@"%@ (%ld)\n%@",
                                                      error.domain ?: @"",
                                                      (long)error.code,
                                                      error.localizedDescription ?: @""];
  [self showMessagePromptWithTitle:@"Error"
                           message:errorMessage
                  showCancelButton:NO
                        completion:^(BOOL userPressedOK,
                                     NSString *_Nullable userInput) {
    [self showMessagePromptWithTitle:@"Profile Info"
                             message:[self stringWithAdditionalUserInfo:result.additionalUserInfo]
                    showCancelButton:NO
                          completion:nil];
    [self updateUserInfo];
  }];
}

- (void)updateUserInfo {
  [_userInfoTableViewCell updateContentsWithUser:[AppManager auth].currentUser];
  [_userInMemoryInfoTableViewCell updateContentsWithUser:_userInMemory];
}

- (void)authStateChangedForAuth:(NSNotification *)notification {
  [self updateUserInfo];
  if (notification) {
    [self log:[NSString stringWithFormat:
       @"received FIRAuthStateDidChange notification on user '%@'.",
       ((FIRAuth *)notification.object).currentUser.uid]];
  }
}

- (void)log:(NSString *)string {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *date = [dateFormatter stringFromDate:[NSDate date]];
    if (!self->_consoleString) {
      self->_consoleString = [NSMutableString string];
    }
    [self->_consoleString appendString:[NSString stringWithFormat:@"%@  %@\n", date, string]];
    self->_consoleTextView.text = self->_consoleString;

    CGRect targetRect = CGRectMake(0, self->_consoleTextView.contentSize.height - 1, 1, 1);
    [self->_consoleTextView scrollRectToVisible:targetRect animated:YES];
  });
}

- (void)logSuccess:(NSString *)string {
  [self log:[NSString stringWithFormat:@"SUCCESS: %@", string]];
}

- (void)logFailure:(NSString *)string error:(NSError * _Nullable) error {
  NSString *message =
  [NSString stringWithFormat:@"FAILURE: %@  Error Description: %@.", string, error.description];
  [self log:message];
}

- (void)logFailedTest:( NSString *_Nonnull )reason {
  [self log:[NSString stringWithFormat:@"FAILIURE: TEST FAILED - %@", reason]];
}

#pragma mark - IBAction

- (IBAction)userToUseDidChange:(UISegmentedControl *)sender {
  _useUserInMemory = (sender.selectedSegmentIndex == 1);
}

- (IBAction)memoryPlus {
  _userInMemory = [AppManager auth].currentUser;
  [self updateUserInfo];
}

- (IBAction)memoryClear {
  _userInMemory = nil;
  [self updateUserInfo];
}

- (IBAction)clearConsole:(id)sender {
  [_consoleString appendString:@"\n\n"];
  _consoleTextView.text = @"";
}

- (IBAction)copyConsole:(id)sender {
  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  pasteboard.string = _consoleString ?: @"";
}

@end

NS_ASSUME_NONNULL_END
