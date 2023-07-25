/*
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <UIKit/UIKit.h>
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPSecret+Internal.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
NS_ASSUME_NONNULL_BEGIN

@implementation FIRTOTPSecret

- (instancetype)initWithSecretKey:(NSString *)secretKey
                 hashingAlgorithm:(NSString *)hashingAlgorithm
                       codeLength:(NSInteger)codeLength
              codeIntervalSeconds:(NSInteger)codeIntervalSeconds
     enrollmentCompletionDeadline:(NSDate *)enrollmentCompletionDeadline
                      sessionInfo:(NSString *)sessionInfo {
  self = [super init];
  if (self) {
    _secretKey = secretKey;
    _hashingAlgorithm = hashingAlgorithm;
    _codeLength = codeLength;
    _codeIntervalSeconds = codeIntervalSeconds;
    _enrollmentCompletionDeadline = [enrollmentCompletionDeadline copy];
    _sessionInfo = sessionInfo;
  }
  return self;
}

- (NSString *)sharedSecretKey {
  return _secretKey;
}

- (NSString *)generateQRCodeURLWithAccountName:(NSString *)accountName issuer:(NSString *)issuer {
  if (!accountName || !self.secretKey || !self.hashingAlgorithm || !self.codeLength) {
    return @"";
  }

  NSString *urlString = [NSString
      stringWithFormat:@"otpauth://totp/%@:%@?secret=%@&issuer=%@&algorithm=%@&digits=%ld", issuer,
                       accountName, self.secretKey, issuer, self.hashingAlgorithm, self.codeLength];
  return urlString;
}

- (void)openInOTPAppWithQRCodeURL:(NSString *)QRCodeURL {
  NSURL *url = [NSURL URLWithString:QRCodeURL];
  static Class applicationClass = nil;
  // iOS App extensions should not call [UIApplication sharedApplication], even if UIApplication
  // responds to it.
  if (![GULAppEnvironmentUtil isAppExtension]) {
    Class cls = NSClassFromString(@"UIApplication");
    if (cls && [cls respondsToSelector:@selector(sharedApplication)]) {
      applicationClass = cls;
    }
  }
  UIApplication *application = [applicationClass sharedApplication];
  if (application) {
    if ([application canOpenURL:url]) {
      SEL selector = @selector(openURL:options:completionHandler:);
      if ([application respondsToSelector:selector]) {
        IMP imp = [application methodForSelector:selector];
        void (*func)(id, SEL, NSURL *, NSDictionary *, void (^)(BOOL)) = (void *)imp;
        func(application, selector, url, @{}, nil);
      } else {
        NSLog(@"Cannot access openURL:options:completionHandler: method");
      }
    } else {
      NSLog(@"URL cannot be opened");
    }
  } else {
    NSLog(@"sharedApplication cannot be accessed");
  }
}

@end

NS_ASSUME_NONNULL_END
#endif
