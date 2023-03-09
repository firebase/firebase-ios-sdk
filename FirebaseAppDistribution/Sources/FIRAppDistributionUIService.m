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

#import "FirebaseAppDistribution/Sources/FIRAppDistributionUIService.h"
#import "FirebaseAppDistribution/Sources/FIRFADLogger.h"
#import "FirebaseAppDistribution/Sources/Public/FirebaseAppDistribution/FIRAppDistribution.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#import <AuthenticationServices/AuthenticationServices.h>
#import <SafariServices/SafariServices.h>
#import <UIKit/UIKit.h>

NSString *const kFIRFADScreenshotFeedbackUserDefault = @"com.firebase.appdistribution.feedback.userdefault";

@import FirebaseAppDistributionInternal;

@interface FIRAppDistributionUIService ()

@property(nonatomic, assign, getter=isListeningToScreenshot) BOOL listeningToScreenshot;

@end

@implementation FIRAppDistributionUIService

API_AVAILABLE(ios(9.0))
SFSafariViewController *_safariVC;

API_AVAILABLE(ios(12.0))
ASWebAuthenticationSession *_webAuthenticationVC;

API_AVAILABLE(ios(11.0))
SFAuthenticationSession *_safariAuthenticationVC;

- (instancetype)init {
  self = [super init];

  self.hostingViewController = [[UIViewController alloc] init];

  return self;
}

+ (instancetype)sharedInstance {
  static dispatch_once_t once;
  static FIRAppDistributionUIService *sharedInstance;
  dispatch_once(&once, ^{
    sharedInstance = [[FIRAppDistributionUIService alloc] init];
  });

  return sharedInstance;
}

+ (NSString *)encodedAppId {
  return [[[FIRApp defaultApp] options].googleAppID stringByReplacingOccurrencesOfString:@":"
                                                                              withString:@"-"];
}

+ (NSError *)getAppDistributionError:(FIRAppDistributionError)appDistributionErrorCode {
  NSString *message = appDistributionErrorCode == FIRAppDistributionErrorAuthenticationCancelled
                          ? @"User cancelled sign-in flow"
                          : @"Failed to authenticate the user";
  NSDictionary *userInfo = @{FIRAppDistributionErrorDetailsKey : message};
  return [NSError errorWithDomain:FIRAppDistributionErrorDomain
                             code:appDistributionErrorCode
                         userInfo:userInfo];
}

+ (NSError *_Nullable)mapErrorToAppDistributionError:(NSError *_Nullable)error {
  if (!error) {
    return nil;
  }

  if (@available(iOS 12.0, *)) {
    if ([error code] == ASWebAuthenticationSessionErrorCodeCanceledLogin) {
      return [self getAppDistributionError:FIRAppDistributionErrorAuthenticationCancelled];
    }
  } else if (@available(iOS 11.0, *)) {
    if ([error code] == SFAuthenticationErrorCanceledLogin) {
      return [self getAppDistributionError:FIRAppDistributionErrorAuthenticationCancelled];
    }
  }

  return [self getAppDistributionError:FIRAppDistributionErrorAuthenticationFailure];
}

// MARK: - Authentication

- (void)appDistributionRegistrationFlow:(NSURL *)URL
                         withCompletion:(void (^)(NSError *_Nullable error))completion {
  NSString *callbackURL =
      [NSString stringWithFormat:@"appdistribution-%@", [[self class] encodedAppId]];

  FIRFADInfoLog(@"Registration URL: %@", URL);
  FIRFADInfoLog(@"Callback URL: %@", callbackURL);

  if (@available(iOS 12.0, *)) {
    ASWebAuthenticationSession *authenticationVC = [[ASWebAuthenticationSession alloc]
              initWithURL:URL
        callbackURLScheme:callbackURL
        completionHandler:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
          [self resetUIState];
          [self logRegistrationCompletion:error authType:[ASWebAuthenticationSession description]];
          NSError *_Nullable appDistributionError =
              [[self class] mapErrorToAppDistributionError:error];
          completion(appDistributionError);
        }];

    if (@available(iOS 13.0, *)) {
      authenticationVC.presentationContextProvider = self;
    }

    _webAuthenticationVC = authenticationVC;

    [authenticationVC start];
  } else if (@available(iOS 11.0, *)) {
    _safariAuthenticationVC = [[SFAuthenticationSession alloc]
              initWithURL:URL
        callbackURLScheme:callbackURL
        completionHandler:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
          [self resetUIState];
          [self logRegistrationCompletion:error authType:[SFAuthenticationSession description]];
          NSError *_Nullable appDistributionError =
              [[self class] mapErrorToAppDistributionError:error];
          completion(appDistributionError);
        }];

    [_safariAuthenticationVC start];
  } else if (@available(iOS 9.0, *)) {
    SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:URL];

    safariVC.delegate = self;
    _safariVC = safariVC;
    [self->_hostingViewController presentViewController:safariVC animated:YES completion:nil];
    self.registrationFlowCompletion = completion;
  }
}

- (void)showUIAlert:(UIAlertController *)alertController {
  [self initializeUIState];
  [self.window.rootViewController presentViewController:alertController
                                               animated:YES
                                             completion:nil];
}

// MARK: - Check for updates

- (void)showCheckForUpdatesUIAlertWithCompletion:(FIRFADUIActionCompletion)completion {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:NSLocalizedString(
                                   @"Enable new build alerts",
                                   @"Title for App Distribution New Build Alerts UIAlert.")
                       message:NSLocalizedString(
                                   @"Get in-app alerts when new builds are ready to test.",
                                   @"Description for enabling new build alerts will do.")
                preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *yesButton = [UIAlertAction
      actionWithTitle:NSLocalizedString(@"Turn on", @"Button for turning on new build alerts.")
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                completion(YES);
              }];

  UIAlertAction *noButton = [UIAlertAction
      actionWithTitle:NSLocalizedString(@"Not now",
                                        @"Button for dismissing the new build alerts UIAlert")
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                [self resetUIState];
                completion(NO);
              }];

  [alert addAction:noButton];
  [alert addAction:yesButton];

  // Create an empty window + viewController to host the Safari UI.
  [self showUIAlert:alert];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
            options:(NSDictionary<NSString *, id> *)options {
  if (self.registrationFlowCompletion) {
    FIRFADDebugLog(@"Continuing registration flow: %@", [self registrationFlowCompletion]);
    [self resetUIState];
    [self logRegistrationCompletion:nil authType:[SFSafariViewController description]];
    self.registrationFlowCompletion(nil);
  }
  return NO;
}

- (void)logRegistrationCompletion:(NSError *)error authType:(NSString *)authType {
  if (error) {
    FIRFADErrorLog(@"Failed to complete App Distribution registration flow. Auth type - %@, Error "
                   @"- %@: %ld. Details - %@",
                   authType, [error domain], (long)[error code], [error localizedDescription]);
  } else {
    FIRFADInfoLog(@"App Distribution Registration complete. Auth type - %@", authType);
  }
}

// MARK: - In App Feedback

- (void)startFeedbackWithAdditionalFormText:(NSString *)additionalFormText image:(UIImage *)image {
  UIViewController *feedbackViewController =
      [FIRFADInAppFeedback feedbackViewControllerWithImage:image
                                                 onDismiss:^() {
                                                   // TODO: Consider using a notification instead of
                                                   // passing this closure.
                                                   // TODO: Consider migrating the UIService to
                                                   // Swift.
                                                   [self resetUIState];
                                                 }];
  [self initializeUIState];
  [self.hostingViewController presentViewController:feedbackViewController
                                           animated:YES
                                         completion:nil];
}

- (void)enableFeedbackOnScreenshotWithAdditionalFormText:(NSString *)additionalFormText
                                           showAlertInfo:(BOOL)showAlertInfo {
  if (!self.isListeningToScreenshot) {
    self.listeningToScreenshot = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(screenshotDetected:)
                                                 name:UIApplicationUserDidTakeScreenshotNotification
                                               object:[UIApplication sharedApplication]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL dontShowAlert = [defaults boolForKey:kFIRFADScreenshotFeedbackUserDefault];
    
    if (showAlertInfo && !dontShowAlert) {
      [self showScreenshotFeedbackUIAlert];
    }
  }
}

- (void)showScreenshotFeedbackUIAlert {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:NSLocalizedString(
                                   @"Send feedback",
                                   @"Title for App Distribution Feedback on Screenshot")
                       message:NSLocalizedString(
                                   @"Take a screenshot to send feedback",
                                   @"Description for sending feedback when a screenshot is taken.")
                preferredStyle:UIAlertControllerStyleAlert];

  UIAlertAction *okButton = [UIAlertAction
      actionWithTitle:NSLocalizedString(@"OK", @"Button for dismissing the feedback alert.")
                style:UIAlertActionStyleDefault
              handler:^(UIAlertAction *action) {
                [self resetUIState];
              }];

  UIAlertAction *dontShowAgainButton = [UIAlertAction
      actionWithTitle:NSLocalizedString(@"Don't show again",
                                        @"Button for not showing the alert again.")
                style:UIAlertActionStyleCancel
              handler:^(UIAlertAction *action) {
                [self resetUIState];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setBool:YES forKey:kFIRFADScreenshotFeedbackUserDefault];
              }];

  [alert addAction:okButton];
  [alert addAction:dontShowAgainButton];
  [self showUIAlert:alert];
}

- (void)screenshotDetected:(NSNotification *)notification {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul), ^{
    [FIRFADInAppFeedback getManuallyCapturedScreenshotWithCompletion:^(UIImage *screenshot) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self startFeedbackWithAdditionalFormText:@"" image:screenshot];
      });
    }];
  });
}

// MARK: - App Distribution UI State

- (void)initializeUIState {
  if (self.window) {
    return;
  }

  if (@available(iOS 13.0, *)) {
    UIWindowScene *foregroundedScene = nil;
    for (UIWindowScene *connectedScene in [UIApplication sharedApplication].connectedScenes) {
      if (connectedScene.activationState == UISceneActivationStateForegroundActive) {
        foregroundedScene = connectedScene;
        break;
      }
    }

    if (foregroundedScene) {
      self.window = [[UIWindow alloc] initWithWindowScene:foregroundedScene];
    } else if ([UIApplication sharedApplication].connectedScenes.count == 1) {
      // There are situations where a scene isn't considered foreground in viewDidAppear
      // and this fixes the issue in single scene apps.
      // https://github.com/firebase/firebase-ios-sdk/issues/8096
      UIWindowScene *scene =
          (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.anyObject;
      self.window = [[UIWindow alloc] initWithWindowScene:scene];
    } else {
      // TODO: Consider using UISceneDidActivateNotification.
      FIRFADInfoLog(@"No foreground scene found.");
      self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
  } else {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  }
  self.window.rootViewController = self.hostingViewController;

  // Place it at the highest level within the stack.
  self.window.windowLevel = +CGFLOAT_MAX;

  // Run it.
  [self.window makeKeyAndVisible];
}

- (void)resetUIState {
  if (self.window) {
    self.window.rootViewController = nil;
    self.window.hidden = YES;
    self.window = nil;
  }

  self.registrationFlowCompletion = nil;

  if (@available(iOS 11.0, *)) {
    _safariAuthenticationVC = nil;
  } else if (@available(iOS 12.0, *)) {
    _webAuthenticationVC = nil;
  } else if (@available(iOS 9.0, *)) {
    _safariVC = nil;
  }
}

- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller NS_AVAILABLE_IOS(9.0) {
  NSError *error =
      [[self class] getAppDistributionError:FIRAppDistributionErrorAuthenticationCancelled];
  [self logRegistrationCompletion:error authType:[SFSafariViewController description]];

  if (self.registrationFlowCompletion) {
    self.registrationFlowCompletion(error);
  }
  [self resetUIState];
}

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:
    (ASWebAuthenticationSession *)session API_AVAILABLE(ios(13.0)) {
  return self.hostingViewController.view.window;
}

@end
