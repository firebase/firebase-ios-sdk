// Copyright 2023 Google LLC
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

#import <XCTest/XCTest.h>

@import FirebaseAuth;

@interface ObjCAPIGlobalTests : XCTestCase
@end

@implementation ObjCAPIGlobalTests

- (void)GlobalSymbolBuildTest {
  __unused NSNotificationName n = FIRAuthStateDidChangeNotification;
  NSString *s = FIRAuthErrorDomain;
  s = FIRAuthErrorUserInfoNameKey;
  s = FIRAuthErrorUserInfoEmailKey;
  s = FIRAuthErrorUserInfoUpdatedCredentialKey;
  s = FIRAuthErrorUserInfoMultiFactorResolverKey;
  s = FIREmailAuthProviderID;
  s = FIREmailLinkAuthSignInMethod;
  s = FIREmailPasswordAuthSignInMethod;
  s = FIRFacebookAuthProviderID;
  s = FIRFacebookAuthSignInMethod;
  s = FIRGameCenterAuthProviderID;
  s = FIRGameCenterAuthSignInMethod;
  s = FIRGitHubAuthProviderID;
  s = FIRGitHubAuthSignInMethod;
  s = FIRGoogleAuthProviderID;
  s = FIRGoogleAuthSignInMethod;
#if TARGET_OS_IOS
  s = FIRPhoneMultiFactorID;
  s = FIRTOTPMultiFactorID;
  s = FIRPhoneAuthProviderID;
  s = FIRPhoneAuthSignInMethod;
#endif
  s = FIRTwitterAuthProviderID;
  s = FIRTwitterAuthSignInMethod;
}
@end
