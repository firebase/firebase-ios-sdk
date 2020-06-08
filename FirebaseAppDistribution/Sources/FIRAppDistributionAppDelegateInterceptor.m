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

@implementation FIRAppDistributionAppDelegatorInterceptor

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
  static FIRAppDistributionAppDelegatorInterceptor *sharedInstance;
  dispatch_once(&once, ^{
    sharedInstance = [[FIRAppDistributionAppDelegatorInterceptor alloc] init];
  });

  return sharedInstance;
}

- (BOOL)openRegistrationFlow:(NSURL *)URL {
  return NO;
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
            options:(NSDictionary<NSString *, id> *)options {
  
  return NO;
}
@end
