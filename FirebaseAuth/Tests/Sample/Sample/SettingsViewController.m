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

#import "SettingsViewController.h"

#import <objc/runtime.h>

#import "AppManager.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSToken.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSTokenManager.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"
#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredentialManager.h"
#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseCore/FIRVersion.h>
#import <FirebaseAuth/FirebaseAuth.h>
#import "StaticContentTableViewManager.h"
#import "UIViewController+Alerts.h"

/** @var kIdentityToolkitRequestClassName
    @brief The class name of Identity Toolkit requests.
 */
static NSString *const kIdentityToolkitRequestClassName = @"FIRIdentityToolkitRequest";

/** @var kSecureTokenRequestClassName
    @brief The class name of Secure Token Service requests.
 */
static NSString *const kSecureTokenRequestClassName = @"FIRSecureTokenRequest";

/** @var kIdentityToolkitSandboxHost
    @brief The host of Identity Toolkit sandbox server.
 */
static NSString *const kIdentityToolkitSandboxHost = @"staging-www.sandbox.googleapis.com";

/** @var kSecureTokenSandboxHost
    @brief The host of Secure Token Service sandbox server.
 */
static NSString *const kSecureTokenSandboxHost = @"staging-securetoken.sandbox.googleapis.com";

/** @var kGoogleServiceInfoPlists
    @brief a C-array of plist file base names of Google service info to initialize FIRApp.
 */
static NSString *const kGoogleServiceInfoPlists[] = {
  @"GoogleService-Info",
  @"GoogleService-Info_multi"
};

/** @var kSharedKeychainAccessGroup
    @brief The shared keychain access group for testing.
 */
static NSString *const kSharedKeychainAccessGroup = @"com.google.firebase.auth.keychainGroup1";

/** @var gAPIEndpoints
    @brief List of API Hosts by request class name.
 */
static NSDictionary<NSString *, NSArray<NSString *> *> *gAPIHosts;

/** @var gFirebaseAppOptions
    @brief List of FIROptions.
 */
static NSArray<FIROptions *> *gFirebaseAppOptions;

/** @protocol RequestClass
    @brief A de-facto protocol followed by request class objects to access its API host.
 */
@protocol RequestClass <NSObject>
- (NSString *)host;
- (void)setHost:(NSString *)host;
@end

/** @fn requestHost
    @brief Retrieves the API host for the request class.
    @param requestClassName The name of the request class.
 */
static NSString *APIHost(NSString *requestClassName) {
  return [(id<RequestClass>)NSClassFromString(requestClassName) host];
}

/** @fn truncatedString
    @brief Truncates a string under a maximum length.
    @param string The original string to be truncated.
    @param length The maximum length of the truncated string.
    @return The truncated string, which is not longer than @c length.
 */
static NSString *truncatedString(NSString *string, NSUInteger length) {
  if (string.length <= length) {
    return string;
  }
  NSUInteger half = (length - 3) / 2;
  return [NSString stringWithFormat:@"%@...%@",
                                    [string substringToIndex:half],
                                    [string substringFromIndex:string.length - half]];
}

@implementation SettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  [self setUpAPIHosts];
  [self setUpFirebaseAppOptions];
  [self loadTableView];
}

- (IBAction)done:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)setUpAPIHosts {
  if (gAPIHosts) {
    return;
  }
  gAPIHosts = @{
    kIdentityToolkitRequestClassName : @[
      APIHost(kIdentityToolkitRequestClassName),
      kIdentityToolkitSandboxHost,
    ],
    kSecureTokenRequestClassName : @[
      APIHost(kSecureTokenRequestClassName),
      kSecureTokenSandboxHost,
    ],
  };
}

- (void)setUpFirebaseAppOptions {
  if (gFirebaseAppOptions) {
    return;
  }
  int numberOfOptions = sizeof(kGoogleServiceInfoPlists) / sizeof(*kGoogleServiceInfoPlists);
  NSMutableArray *appOptions = [[NSMutableArray alloc] initWithCapacity:numberOfOptions];
  for (int i = 0; i < numberOfOptions; i++) {
    NSString *plistFileName = kGoogleServiceInfoPlists[i];
    NSString *plistFilePath = [[NSBundle mainBundle] pathForResource:plistFileName
                                                              ofType:@"plist"];
    FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:plistFilePath];
    [appOptions addObject:options];
  }
  gFirebaseAppOptions = [appOptions copy];
}

- (void)loadTableView {
  NSString *appIdentifierPrefix = NSBundle.mainBundle.infoDictionary[@"AppIdentifierPrefix"];
  NSString *fullKeychainAccessGroup = [appIdentifierPrefix stringByAppendingString:kSharedKeychainAccessGroup];

  __weak typeof(self) weakSelf = self;
  _tableViewManager.contents = [StaticContentTableViewContent contentWithSections:@[
    [StaticContentTableViewSection sectionWithTitle:@"Versions" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"FirebaseAuth"
                                          value:FIRFirebaseVersion()],
    ]],
    [StaticContentTableViewSection sectionWithTitle:@"API Hosts" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"Identity Toolkit"
                                          value:APIHost(kIdentityToolkitRequestClassName)
                                         action:^{
        [weakSelf toggleAPIHostWithRequestClassName:kIdentityToolkitRequestClassName];
      }],
      [StaticContentTableViewCell cellWithTitle:@"Secure Token"
                                          value:APIHost(kSecureTokenRequestClassName)
                                         action:^{
        [weakSelf toggleAPIHostWithRequestClassName:kSecureTokenRequestClassName];
      }],
    ]],
    [StaticContentTableViewSection sectionWithTitle:@"Firebase Apps" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"Active App"
                                          value:[self activeAppDescription]
                                         action:^{
        [weakSelf toggleActiveApp];
      }],
      [StaticContentTableViewCell cellWithTitle:@"Default App"
                                          value:[self projectIDForAppAtIndex:0]
                                         action:^{
        [weakSelf toggleProjectForAppAtIndex:0];
      }],
      [StaticContentTableViewCell cellWithTitle:@"Other App"
                                          value:[self projectIDForAppAtIndex:1]
                                         action:^{
        [weakSelf toggleProjectForAppAtIndex:1];
      }],
    ]],
    [StaticContentTableViewSection sectionWithTitle:@"Keychain Access Groups" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"Current Access Group"
                                          value:[AppManager auth].userAccessGroup ? [AppManager auth].userAccessGroup : @"[none]"
      ],
      [StaticContentTableViewCell cellWithTitle:@"Default Group"
                                          value:@"[none]"
                                         action:^{
                                           [[AppManager auth] useUserAccessGroup:nil error:nil];
                                           [self loadTableView];
      }],
      [StaticContentTableViewCell cellWithTitle:@"Shared Group"
                                          value:fullKeychainAccessGroup
                                         action:^{
                                           [[AppManager auth] useUserAccessGroup:fullKeychainAccessGroup error:nil];
                                           [self loadTableView];
      }],
    ]],
    [StaticContentTableViewSection sectionWithTitle:@"Phone Auth" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"APNs Token"
                                          value:[self APNSTokenString]
                                         action:^{
        [weakSelf clearAPNSToken];
      }],
      [StaticContentTableViewCell cellWithTitle:@"App Credential"
                                          value:[self appCredentialString]
                                         action:^{
        [weakSelf clearAppCredential];
      }],
    ]],
    [StaticContentTableViewSection sectionWithTitle:@"Language" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"Auth Language"
                                          value:[AppManager auth].languageCode ?: @"[none]"
                                         action:^{
        [weakSelf showLanguageInput];
      }],
      [StaticContentTableViewCell cellWithTitle:@"Use App language" action:^{
        [[AppManager auth] useAppLanguage];
        [weakSelf loadTableView];
      }],
    ]],
    [StaticContentTableViewSection sectionWithTitle:@"Auth Settings" cells:@[
      [StaticContentTableViewCell cellWithTitle:@"Disable App Verification (Phone)"
                                          value:[AppManager auth].settings.
                                              appVerificationDisabledForTesting ? @"Yes" : @"No"
                                         action:^{
        [weakSelf toggleDisableAppVerification];
        [weakSelf loadTableView];
      }],
    ]],
  ]];
}

/** @fn toggleDisableAppVerification
    @brief Toggles the appVerificationDisabledForTesting flag on the current Auth instance.
 */
- (void)toggleDisableAppVerification {
  [AppManager auth].settings.appVerificationDisabledForTesting =
      ![AppManager auth].settings.appVerificationDisabledForTesting;
}

/** @fn toggleAPIHostWithRequestClassName:
    @brief Toggles the host name of the server that handles RPCs.
    @param requestClassName The name of the RPC request class.
 */
- (void)toggleAPIHostWithRequestClassName:(NSString *)requestClassName {
  NSString *currentHost = APIHost(requestClassName);
  NSArray<NSString *> *allHosts = gAPIHosts[requestClassName];
  NSString *newHost = allHosts[([allHosts indexOfObject:currentHost] + 1) % allHosts.count];
  [(id<RequestClass>)NSClassFromString(requestClassName) setHost:newHost];
  [self loadTableView];
}

/** @fn activeAppDescription
    @brief Returns the description for the currently active Firebase app.
 */
- (NSString *)activeAppDescription {
  return [AppManager sharedInstance].active == 0 ? @"[Default]" : @"[Other]";
}

/** @fn toggleActiveApp
    @brief Toggles the active Firebase app for the rest of the application.
 */
- (void)toggleActiveApp {
  AppManager *apps = [AppManager sharedInstance];
  // This changes the FIRAuth instance returned from `[AppManager auth]` to be one that is
  // associated with a different `FIRApp` instance. The sample app uses `[AppManager auth]`
  // instead of `[FIRAuth auth]` almost everywhere. Thus, this statement switches between default
  // and non-default `FIRApp` instances for the sample app to test against.
  apps.active = (apps.active + 1) % apps.count;
  [self loadTableView];
}

/** @fn projectIDForAppAtIndex:
    @brief Returns the Firebase project ID for the Firebase app at the given index.
    @param index The index for the app in the app manager.
    @return The ID of the project.
 */
- (NSString *)projectIDForAppAtIndex:(int)index {
  NSString *APIKey = [[AppManager sharedInstance] appAtIndex:index].options.APIKey;
  for (FIROptions *options in gFirebaseAppOptions) {
    if ([options.APIKey isEqualToString:APIKey]) {
      return options.projectID;
    }
  }
  return @"[none]";
}

/** @fn projectIDForAppAtIndex:
    @brief Returns the Firebase project ID for the Firebase app at the given index.
    @param index The index for the app in the app manager.
    @return The ID of the project.
 */
- (NSString *)keychainAccessGroupAtIndex:(int)index {
  NSArray *array = @[@"123", @"456"];
  return array[index];
}

/** @fn toggleProjectForAppAtIndex:
    @brief Toggles the Firebase project for the Firebase app at the given index by recreating the
        FIRApp instance with different options.
    @param index The index for the app to be recreated in the app manager.
 */
- (void)toggleProjectForAppAtIndex:(int)index {
  NSString *APIKey = [[AppManager sharedInstance] appAtIndex:index].options.APIKey;
  int optionIndex;
  for (optionIndex = 0; optionIndex < gFirebaseAppOptions.count; optionIndex++) {
    FIROptions *options = gFirebaseAppOptions[optionIndex];
    if ([options.APIKey isEqualToString:APIKey]) {
      break;
    }
  }

  FIROptions *options;
  if (index == 0) {
    // For default apps, the next options cannot be `nil`.
    optionIndex = (optionIndex + 1) % gFirebaseAppOptions.count;
    options = gFirebaseAppOptions[optionIndex];
  } else {
    // For non-default apps, `nil` is considered the next options after the last options in the array.
    optionIndex = (optionIndex + 1) % (gFirebaseAppOptions.count + 1);
    if (optionIndex != gFirebaseAppOptions.count) {
      options = gFirebaseAppOptions[optionIndex];
    }
  }
  __weak typeof(self) weakSelf = self;
  [[AppManager sharedInstance] recreateAppAtIndex:index withOptions:options completion:^() {
    dispatch_async(dispatch_get_main_queue(), ^() {
      [weakSelf loadTableView];
    });
  }];
}

/** @fn APNSTokenString
    @brief Returns a string representing APNS token.
 */
- (NSString *)APNSTokenString {
  FIRAuthAPNSToken *token = [AppManager auth].tokenManager.token;
  if (!token) {
    return @"";
  }
  return [NSString stringWithFormat:@"%@(%@)",
                                    truncatedString(token.string, 19),
                                    token.type == FIRAuthAPNSTokenTypeProd ? @"P" : @"S"];
}

/** @fn clearAPNSToken
    @brief Clears the saved app credential.
 */
- (void)clearAPNSToken {
  FIRAuthAPNSToken *token = [AppManager auth].tokenManager.token;
  if (!token) {
    return;
  }
  NSString *tokenType = token.type == FIRAuthAPNSTokenTypeProd ? @"Production" : @"Sandbox";
  NSString *message = [NSString stringWithFormat:@"token: %@\ntype: %@",
                                                 token.string, tokenType];
  [self showMessagePromptWithTitle:@"Clear APNs Token?"
                           message:message
                  showCancelButton:YES
                        completion:^(BOOL userPressedOK, NSString *_Nullable userInput) {
    if (userPressedOK) {
      [AppManager auth].tokenManager.token = nil;
      [self loadTableView];
    }
  }];
}

/** @fn appCredentialString
    @brief Returns a string representing app credential.
 */
- (NSString *)appCredentialString {
  FIRAuthAppCredential *credential = [AppManager auth].appCredentialManager.credential;
  if (!credential) {
    return @"";
  }
  return [NSString stringWithFormat:@"%@/%@",
                                    truncatedString(credential.receipt, 13),
                                    truncatedString(credential.secret, 13)];
}

/** @fn clearAppCredential
    @brief Clears the saved app credential.
 */
- (void)clearAppCredential {
  FIRAuthAppCredential *credential = [AppManager auth].appCredentialManager.credential;
  if (!credential) {
    return;
  }
  NSString *message = [NSString stringWithFormat:@"receipt: %@\nsecret: %@",
                                                 credential.receipt, credential.secret];
  [self showMessagePromptWithTitle:@"Clear App Credential?"
                           message:message
                  showCancelButton:YES
                        completion:^(BOOL userPressedOK, NSString *_Nullable userInput) {
    if (userPressedOK) {
      [[AppManager auth].appCredentialManager clearCredential];
      [self loadTableView];
    }
  }];
}

/** @fn showLanguageInput
    @brief Show language code input field.
 */
- (void)showLanguageInput {
  [self showTextInputPromptWithMessage:@"Enter Language Code For Auth:"
                       completionBlock:^(BOOL userPressedOK, NSString *_Nullable languageCode) {
    if (!userPressedOK) {
      return;
    }
    [AppManager auth].languageCode = languageCode.length ? languageCode : nil;
    [self loadTableView];
  }];
}

@end
