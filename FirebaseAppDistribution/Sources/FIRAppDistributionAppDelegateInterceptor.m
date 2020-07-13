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

#import "FIRAppDistributionAppDelegateInterceptor.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import <SafariServices/SafariServices.h>
#import <UIKit/UIKit.h>

@implementation FIRAppDistributionAppDelegateInterceptor

API_AVAILABLE(ios(9.0))
SFSafariViewController *_safariVC;

API_AVAILABLE(ios(12.0))
ASWebAuthenticationSession *_webAuthenticationVC;

API_AVAILABLE(ios(11.0))
SFAuthenticationSession *_safariAuthenticationVC;

- (instancetype)init {
  self = [super init];
  
  self.safariHostingViewController = [[UIViewController alloc] init];

  
  return self;
}

+ (instancetype)sharedInstance {
  static dispatch_once_t once;
  static FIRAppDistributionAppDelegateInterceptor *sharedInstance;
  dispatch_once(&once, ^{
    sharedInstance = [[FIRAppDistributionAppDelegateInterceptor alloc] init];
  });

  return sharedInstance;
}

- (void)appDistributionRegistrationFlow:(NSURL *)URL
                         withCompletion:(void (^)(NSError *_Nullable error))completion {
     NSLog(@"Registration URL: %@", URL);

        SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:URL];

        safariVC.delegate = self;
        _safariVC = safariVC;
        [self->_safariHostingViewController presentViewController:safariVC
                                                         animated:YES
                                                       completion:nil];
        
        self.registrationFlowCompletion = completion;
        
//        if (@available(iOS 12.0, *)) {
//          ASWebAuthenticationSession *authenticationVC = [[ASWebAuthenticationSession alloc]
//                    initWithURL:URL
//              callbackURLScheme:@"com.firebase.appdistribution"
//              completionHandler:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
//                [self resetUIState];
//                NSLog(@"Testing: Sign in Complete!");
//                completion(error);
////                if (callbackURL) {
////                  self.isTesterSignedIn = true;
////                  completion(nil);
////                } else {
////                  self.isTesterSignedIn = false;
////                  completion(error);
////                }
//              }];
//
//          if (@available(iOS 13.0, *)) {
//            authenticationVC.presentationContextProvider = self;
//          }
//
//          _webAuthenticationVC = authenticationVC;
//
//          [authenticationVC start];
//        } else if (@available(iOS 11.0, *)) {
//          _safariAuthenticationVC = [[SFAuthenticationSession alloc]
//                    initWithURL:URL
//              callbackURLScheme:@"com.firebase.appdistribution"
//              completionHandler:^(NSURL *_Nullable callbackURL, NSError *_Nullable error) {
//                [self resetUIState];
//                NSLog(@"Testing: Sign in Complete!");
//                completion(error);
////                if (callbackURL) {
////                  self.isTesterSignedIn = true;
////                  completion(nil);
////                } else {
////                  self.isTesterSignedIn = false;
////                  completion(error);
////                }
//              }];
//
//          [_safariAuthenticationVC start];
//        } else {
//          SFSafariViewController *safariVC = [[SFSafariViewController alloc] initWithURL:URL];
//
//          safariVC.delegate = self;
//          _safariVC = safariVC;
//          [self->_safariHostingViewController presentViewController:safariVC
//                                                           animated:YES
//                                                         completion:nil];
//        }
}


-(void)showUIAlert:(UIAlertController *)alertController {
    [self initializeUIState];
    [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
}


- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
            options:(NSDictionary<NSString *, id> *)options {
  self.registrationFlowCompletion(nil);
    [self resetUIState];
  return NO;
}

- (void)initializeUIState {
  if (self.window) {
    return;
  }
  // Create an empty window + viewController to host the Safari UI.
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.rootViewController = self.safariHostingViewController;

  // Place it at the highest level within the stack.
  self.window.windowLevel = +CGFLOAT_MAX;

  // Run it.
  [self.window makeKeyAndVisible];
}


- (void) resetUIState {
  if (self.window) {
    self.window.hidden = YES;
    self.window = nil;
  }
    
    self.registrationFlowCompletion = nil;

    if (@available(iOS 11.0, *)) {
        _safariAuthenticationVC = nil;
    }
    else if (@available(iOS 12.0, *)) {
        _webAuthenticationVC = nil;
    }
    else if (@available(iOS 9.0, *)) {
        _safariVC = nil;
    }
}



- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller NS_AVAILABLE_IOS(9.0) {
  [self resetUIState];
}

- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:
    (ASWebAuthenticationSession *)session API_AVAILABLE(ios(13.0)) {
  return self.safariHostingViewController.view.window;
}

@end
