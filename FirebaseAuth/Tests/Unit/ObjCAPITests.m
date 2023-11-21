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

@import FirebaseCore;
@import FirebaseAuth;

#if !TARGET_OS_OSX && !TARGET_OS_WATCH
@interface AuthUIImpl : NSObject <FIRAuthUIDelegate>
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^_Nullable)(void))completion;
- (void)presentViewController:(nonnull UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^_Nullable)(void))completion;
@end
@implementation AuthUIImpl
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^_Nullable)(void))completion {
}

- (void)presentViewController:(nonnull UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^_Nullable)(void))completion {
}
@end
#endif

#if TARGET_OS_IOS
@interface FederatedAuthImplementation : NSObject <FIRFederatedAuthProvider>
- (void)getCredentialWithUIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
                         completion:(nullable void (^)(FIRAuthCredential *_Nullable,
                                                       NSError *_Nullable))completion;
@end
@implementation FederatedAuthImplementation
- (void)getCredentialWithUIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
                         completion:(nullable void (^)(FIRAuthCredential *_Nullable,
                                                       NSError *_Nullable))completion {
}
@end
#endif

@interface ObjCAPICoverage : XCTestCase
@end

@implementation ObjCAPICoverage

- (void)FIRActionCodeSettings_h {
  FIRActionCodeSettings *codeSettings = [[FIRActionCodeSettings alloc] init];
  [codeSettings setIOSBundleID:@"abc"];
  [codeSettings setAndroidPackageName:@"name" installIfNotAvailable:NO minimumVersion:@"1.1"];
  BOOL b = [codeSettings handleCodeInApp];
  b = [codeSettings androidInstallIfNotAvailable];
  __unused NSURL *u = [codeSettings URL];
  NSString *s = [codeSettings iOSBundleID];
  s = [codeSettings androidPackageName];
  s = [codeSettings androidMinimumVersion];
  s = [codeSettings dynamicLinkDomain];
}

- (void)FIRAuthAdditionalUserInfo_h:(FIRAdditionalUserInfo *)additionalUserInfo {
  NSString *s = [additionalUserInfo providerID];
  __unused BOOL b = [additionalUserInfo isNewUser];
  __unused NSDictionary<NSString *, NSObject *> *dict = [additionalUserInfo profile];
  s = [additionalUserInfo username];
}

- (void)ActionCodeOperationTests:(FIRActionCodeInfo *)info {
  __unused FIRActionCodeOperation op = [info operation];
  NSString *s = [info email];
  s = [info previousEmail];
}

- (void)ActionCodeURL:(FIRActionCodeURL *)url {
  __unused FIRActionCodeOperation op = [url operation];
  NSString *s = [url APIKey];
  s = [url code];
  __unused NSURL *u = [url continueURL];
  s = [url languageCode];
}

- (void)authProperties:(FIRAuth *)auth {
  __unused BOOL b = [auth shareAuthStateAcrossDevices];
  [auth setShareAuthStateAcrossDevices:YES];
  __unused FIRUser *u = [auth currentUser];
  NSString *s = [auth languageCode];
  [auth setLanguageCode:s];
  FIRAuthSettings *settings = [auth settings];
  [auth setSettings:settings];
  s = [auth userAccessGroup];
  s = [auth tenantID];
  [auth setTenantID:s];
  s = [auth customAuthDomain];
  [auth setCustomAuthDomain:s];
#if TARGET_OS_IOS
  __unused NSData *d = [auth APNSToken];
  auth.APNSToken = [[NSData alloc] init];
#endif
}

- (void)FIRAuth_h:(FIRAuth *)auth
             with:(FIRAuthCredential *)credential
         provider:(FIROAuthProvider *)provider
              url:(NSURL *)url {
  [auth updateCurrentUser:[auth currentUser]
               completion:^(NSError *_Nullable error){
               }];
  [auth signInWithEmail:@"a@abc.com"
               password:@"pw"
             completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
             }];
#if !TARGET_OS_WATCH
  [auth signInWithEmail:@"a@abc.com"
                   link:@"link"
             completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
             }];
#endif
#if TARGET_OS_IOS
  [auth signInWithProvider:provider
                UIDelegate:nil
                completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
                }];
  [auth signInWithCredential:credential
                  completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
                  }];
#endif
  [auth signInAnonymouslyWithCompletion:^(FIRAuthDataResult *_Nullable authResult,
                                          NSError *_Nullable error){
  }];
  [auth signInWithCustomToken:@"token"
                   completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
                   }];
  [auth createUserWithEmail:@"a@abc.com"
                   password:@"pw"
                 completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
                 }];
  [auth confirmPasswordResetWithCode:@"code"
                         newPassword:@"pw"
                          completion:^(NSError *_Nullable error){
                          }];
  [auth checkActionCode:@"code"
             completion:^(FIRActionCodeInfo *_Nullable info, NSError *_Nullable error){
             }];
  [auth verifyPasswordResetCode:@"code"
                     completion:^(NSString *_Nullable email, NSError *_Nullable error){
                     }];
  [auth applyActionCode:@"code"
             completion:^(NSError *_Nullable error){
             }];
  [auth sendPasswordResetWithEmail:@"email"
                        completion:^(NSError *_Nullable error){
                        }];
  FIRActionCodeSettings *settings = [[FIRActionCodeSettings alloc] init];
  [auth sendPasswordResetWithEmail:@"email"
                actionCodeSettings:settings
                        completion:^(NSError *_Nullable error){
                        }];
#if !TARGET_OS_WATCH
  [auth sendSignInLinkToEmail:@"email"
           actionCodeSettings:settings
                   completion:^(NSError *_Nullable error){
                   }];
#endif
  NSError *error;
  [auth signOut:&error];
  __unused BOOL b;
#if !TARGET_OS_WATCH
  b = [auth isSignInWithEmailLink:@"email"];
#endif
  FIRAuthStateDidChangeListenerHandle handle =
      [auth addAuthStateDidChangeListener:^(FIRAuth *_Nonnull auth, FIRUser *_Nullable user){
      }];
  [auth removeAuthStateDidChangeListener:handle];
  [auth removeIDTokenDidChangeListener:handle];
  [auth useAppLanguage];
  [auth useEmulatorWithHost:@"host" port:123];
#if TARGET_OS_IOS
  b = [auth canHandleURL:url];
  [auth setAPNSToken:[[NSData alloc] init] type:FIRAuthAPNSTokenTypeProd];
  b = [auth canHandleNotification:@{}];
#if !TARGET_OS_MACCATALYST && (!defined(TARGET_OS_VISION) || !TARGET_OS_VISION)
  [auth initializeRecaptchaConfigWithCompletion:^(NSError *_Nullable error){
  }];
#endif
#endif
  [auth revokeTokenWithAuthorizationCode:@"a"
                              completion:^(NSError *_Nullable error){
                              }];
  [auth useUserAccessGroup:@"abc" error:&error];
  __unused FIRUser *u = [auth getStoredUserForAccessGroup:@"user" error:&error];
}

#if !TARGET_OS_OSX
- (void)FIRAuthAPNSTokenType_h {
  FIRAuthAPNSTokenType t = FIRAuthAPNSTokenTypeProd;
  t = FIRAuthAPNSTokenTypeSandbox;
  t = FIRAuthAPNSTokenTypeUnknown;
}
#endif

- (NSString *)authCredential:(FIRAuthCredential *)credential {
  return [credential provider];
}

- (void)authDataResult:(FIRAuthDataResult *)result {
  __unused FIRUser *u = [result user];
  __unused FIRAdditionalUserInfo *info = [result additionalUserInfo];
  __unused FIRAuthCredential *c = [result credential];
}

- (void)FIRAuthErrors_h {
  FIRAuthErrorCode c = FIRAuthErrorCodeInvalidCustomToken;
  c = FIRAuthErrorCodeCustomTokenMismatch;
  c = FIRAuthErrorCodeInvalidCredential;
  c = FIRAuthErrorCodeUserDisabled;
  c = FIRAuthErrorCodeOperationNotAllowed;
  c = FIRAuthErrorCodeEmailAlreadyInUse;
  c = FIRAuthErrorCodeInvalidEmail;
  c = FIRAuthErrorCodeWrongPassword;
  c = FIRAuthErrorCodeTooManyRequests;
  c = FIRAuthErrorCodeUserNotFound;
  c = FIRAuthErrorCodeAccountExistsWithDifferentCredential;
  c = FIRAuthErrorCodeRequiresRecentLogin;
  c = FIRAuthErrorCodeProviderAlreadyLinked;
  c = FIRAuthErrorCodeNoSuchProvider;
  c = FIRAuthErrorCodeInvalidUserToken;
  c = FIRAuthErrorCodeNetworkError;
  c = FIRAuthErrorCodeUserTokenExpired;
  c = FIRAuthErrorCodeInvalidAPIKey;
  c = FIRAuthErrorCodeUserMismatch;
  c = FIRAuthErrorCodeCredentialAlreadyInUse;
  c = FIRAuthErrorCodeWeakPassword;
  c = FIRAuthErrorCodeAppNotAuthorized;
  c = FIRAuthErrorCodeExpiredActionCode;
  c = FIRAuthErrorCodeInvalidActionCode;
  c = FIRAuthErrorCodeInvalidMessagePayload;
  c = FIRAuthErrorCodeInvalidSender;
  c = FIRAuthErrorCodeInvalidRecipientEmail;
  c = FIRAuthErrorCodeMissingEmail;
  c = FIRAuthErrorCodeMissingIosBundleID;
  c = FIRAuthErrorCodeMissingAndroidPackageName;
  c = FIRAuthErrorCodeUnauthorizedDomain;
  c = FIRAuthErrorCodeInvalidContinueURI;
  c = FIRAuthErrorCodeMissingContinueURI;
  c = FIRAuthErrorCodeMissingPhoneNumber;
  c = FIRAuthErrorCodeInvalidPhoneNumber;
  c = FIRAuthErrorCodeMissingVerificationCode;
  c = FIRAuthErrorCodeInvalidVerificationCode;
  c = FIRAuthErrorCodeMissingVerificationID;
  c = FIRAuthErrorCodeInvalidVerificationID;
  c = FIRAuthErrorCodeMissingAppCredential;
  c = FIRAuthErrorCodeInvalidAppCredential;
  c = FIRAuthErrorCodeSessionExpired;
  c = FIRAuthErrorCodeQuotaExceeded;
  c = FIRAuthErrorCodeMissingAppToken;
  c = FIRAuthErrorCodeNotificationNotForwarded;
  c = FIRAuthErrorCodeAppNotVerified;
  c = FIRAuthErrorCodeCaptchaCheckFailed;
  c = FIRAuthErrorCodeWebContextAlreadyPresented;
  c = FIRAuthErrorCodeWebContextCancelled;
  c = FIRAuthErrorCodeAppVerificationUserInteractionFailure;
  c = FIRAuthErrorCodeInvalidClientID;
  c = FIRAuthErrorCodeWebNetworkRequestFailed;
  c = FIRAuthErrorCodeWebInternalError;
  c = FIRAuthErrorCodeWebSignInUserInteractionFailure;
  c = FIRAuthErrorCodeLocalPlayerNotAuthenticated;
  c = FIRAuthErrorCodeNullUser;
  c = FIRAuthErrorCodeDynamicLinkNotActivated;
  c = FIRAuthErrorCodeInvalidProviderID;
  c = FIRAuthErrorCodeTenantIDMismatch;
  c = FIRAuthErrorCodeUnsupportedTenantOperation;
  c = FIRAuthErrorCodeInvalidDynamicLinkDomain;
  c = FIRAuthErrorCodeRejectedCredential;
  c = FIRAuthErrorCodeGameKitNotLinked;
  c = FIRAuthErrorCodeSecondFactorRequired;
  c = FIRAuthErrorCodeMissingMultiFactorSession;
  c = FIRAuthErrorCodeMissingMultiFactorInfo;
  c = FIRAuthErrorCodeInvalidMultiFactorSession;
  c = FIRAuthErrorCodeMultiFactorInfoNotFound;
  c = FIRAuthErrorCodeAdminRestrictedOperation;
  c = FIRAuthErrorCodeUnverifiedEmail;
  c = FIRAuthErrorCodeSecondFactorAlreadyEnrolled;
  c = FIRAuthErrorCodeMaximumSecondFactorCountExceeded;
  c = FIRAuthErrorCodeUnsupportedFirstFactor;
  c = FIRAuthErrorCodeEmailChangeNeedsVerification;
  c = FIRAuthErrorCodeMissingClientIdentifier;
  c = FIRAuthErrorCodeMissingOrInvalidNonce;
  c = FIRAuthErrorCodeBlockingCloudFunctionError;
  c = FIRAuthErrorCodeRecaptchaNotEnabled;
  c = FIRAuthErrorCodeMissingRecaptchaToken;
  c = FIRAuthErrorCodeInvalidRecaptchaToken;
  c = FIRAuthErrorCodeInvalidRecaptchaAction;
  c = FIRAuthErrorCodeMissingClientType;
  c = FIRAuthErrorCodeMissingRecaptchaVersion;
  c = FIRAuthErrorCodeInvalidRecaptchaVersion;
  c = FIRAuthErrorCodeInvalidReqType;
  c = FIRAuthErrorCodeRecaptchaSDKNotLinked;
  c = FIRAuthErrorCodeKeychainError;
  c = FIRAuthErrorCodeInternalError;
  c = FIRAuthErrorCodeMalformedJWT;
}

- (void)authSettings:(FIRAuthSettings *)settings {
  BOOL b = [settings isAppVerificationDisabledForTesting];
  [settings setAppVerificationDisabledForTesting:b];
}

- (void)authTokenResult:(FIRAuthTokenResult *)result {
  NSString *s = [result token];
  NSDate *d = [result expirationDate];
  d = [result authDate];
  d = [result issuedAtDate];
  s = [result signInProvider];
  s = [result signInSecondFactor];
  __unused NSDictionary<NSString *, NSObject *> *dict = [result claims];
}

#if !TARGET_OS_OSX && !TARGET_OS_WATCH
- (void)authTokenResult {
  AuthUIImpl *impl = [[AuthUIImpl alloc] init];
  [impl presentViewController:[[UIViewController alloc] init]
                     animated:NO
                   completion:^{
                   }];
  [impl dismissViewControllerAnimated:YES
                           completion:^{
                           }];
}
#endif

- (void)FIREmailAuthProvider_h {
  FIRAuthCredential *c = [FIREmailAuthProvider credentialWithEmail:@"e" password:@"pw"];
  c = [FIREmailAuthProvider credentialWithEmail:@"e" link:@"l"];
}

- (void)FIRFacebookAuthProvider_h {
  __unused FIRAuthCredential *c = [FIRFacebookAuthProvider credentialWithAccessToken:@"token"];
}

#if TARGET_OS_IOS
- (void)FIRFederatedAuthProvider_h {
  FederatedAuthImplementation *impl = [[FederatedAuthImplementation alloc] init];
  [impl getCredentialWithUIDelegate:nil
                         completion:^(FIRAuthCredential *_Nullable c, NSError *_Nullable e){
                         }];
}
#endif

#if !TARGET_OS_WATCH
- (void)FIRGameCenterAuthProvider_h {
  [FIRGameCenterAuthProvider getCredentialWithCompletion:^(FIRAuthCredential *_Nullable credential,
                                                           NSError *_Nullable error){
  }];
}
#endif

- (void)FIRGitHubAuthProvider_h {
  __unused FIRAuthCredential *c = [FIRGitHubAuthProvider credentialWithToken:@"token"];
}

- (void)FIRGoogleAuthProvider_h {
  __unused FIRAuthCredential *c = [FIRGoogleAuthProvider credentialWithIDToken:@"token"
                                                                   accessToken:@"token"];
}

#if TARGET_OS_IOS
- (void)FIRMultiFactor_h:(FIRMultiFactor *)mf mfa:(FIRMultiFactorAssertion *)mfa {
  [mf getSessionWithCompletion:^(FIRMultiFactorSession *_Nullable credential,
                                 NSError *_Nullable error){
  }];
  [mf enrollWithAssertion:mfa
              displayName:@"name"
               completion:^(NSError *_Nullable error){
               }];
  FIRMultiFactorInfo *mfi = [mf enrolledFactors][0];
  [mf unenrollWithInfo:mfi
            completion:^(NSError *_Nullable error){
            }];
  [mf unenrollWithFactorUID:@"uid"
                 completion:^(NSError *_Nullable error){
                 }];
}

- (void)multiFactorAssertion:(FIRMultiFactorAssertion *)mfa {
  __unused NSString *s = [mfa factorID];
}

- (void)multiFactorInfo:(FIRMultiFactorInfo *)mfi {
  NSString *s = [mfi UID];
  s = [mfi factorID];
  s = [mfi displayName];
  __unused NSDate *d = [mfi enrollmentDate];
}

- (void)multiFactorResolver:(FIRMultiFactorResolver *)mfr {
  __unused FIRMultiFactorSession *s = [mfr session];
  __unused NSArray<FIRMultiFactorInfo *> *hints = [mfr hints];
  __unused FIRAuth *auth = [mfr auth];
}
#endif

- (void)oauthCredential:(FIROAuthCredential *)credential {
  NSString *s = [credential IDToken];
  s = [credential accessToken];
  s = [credential secret];
}

#if TARGET_OS_IOS
- (void)FIROAuthProvider_h:(FIROAuthProvider *)provider {
  FIROAuthCredential *c = [FIROAuthProvider credentialWithProviderID:@"id" accessToken:@"token"];
  c = [FIROAuthProvider credentialWithProviderID:@"id"
                                         IDToken:@"idToken"
                                     accessToken:@"accessToken"];
  c = [FIROAuthProvider credentialWithProviderID:@"id" IDToken:@"idtoken" rawNonce:@"nonce"];
  c = [FIROAuthProvider credentialWithProviderID:@"id"
                                         IDToken:@"token"
                                        rawNonce:@"nonce"
                                     accessToken:@"accessToken"];
  c = [FIROAuthProvider appleCredentialWithIDToken:@"idToken" rawNonce:@"nonce" fullName:nil];
  [provider getCredentialWithUIDelegate:nil
                             completion:^(FIRAuthCredential *_Nullable credential,
                                          NSError *_Nullable error){
                             }];
  __unused NSString *s = [provider providerID];
  __unused NSArray<NSString *> *scopes = [provider scopes];
  __unused NSDictionary<NSString *, NSString *> *params = [provider customParameters];
}

- (void)FIRPhoneAuthProvider_h:(FIRPhoneAuthProvider *)provider mfi:(FIRPhoneMultiFactorInfo *)mfi {
  [provider verifyPhoneNumber:@"123"
                   UIDelegate:nil
                   completion:^(NSString *_Nullable verificationID, NSError *_Nullable error){
                   }];
  [provider verifyPhoneNumber:@"123"
                   UIDelegate:nil
           multiFactorSession:nil
                   completion:^(NSString *_Nullable verificationID, NSError *_Nullable error){
                   }];
  [provider verifyPhoneNumberWithMultiFactorInfo:mfi
                                      UIDelegate:nil
                              multiFactorSession:nil
                                      completion:^(NSString *_Nullable verificationID,
                                                   NSError *_Nullable error){
                                      }];
  __unused FIRPhoneAuthCredential *c = [provider credentialWithVerificationID:@"id"
                                                             verificationCode:@"code"];
}

- (void)FIRPhoneAuthProvider_h:(FIRPhoneAuthCredential *)credential {
  __unused FIRPhoneMultiFactorAssertion *a =
      [FIRPhoneMultiFactorGenerator assertionWithCredential:credential];
}

- (void)phoneMultiFactorInfo:(FIRPhoneMultiFactorInfo *)info {
  __unused NSString *s = [info phoneNumber];
}

- (void)FIRTOTPSecret_h:(FIRTOTPSecret *)secret {
  NSString *s = [secret sharedSecretKey];
  s = [secret generateQRCodeURLWithAccountName:@"name" issuer:@"issuer"];
  [secret openInOTPAppWithQRCodeURL:@"qr"];
}

- (void)FIRTOTPMultiFactorGenerator_h:(FIRMultiFactorSession *)session
                               secret:(FIRTOTPSecret *)secret {
  [FIRTOTPMultiFactorGenerator
      generateSecretWithMultiFactorSession:session
                                completion:^(FIRTOTPSecret *_Nullable secret,
                                             NSError *_Nullable error){
                                }];
  FIRTOTPMultiFactorAssertion *a =
      [FIRTOTPMultiFactorGenerator assertionForEnrollmentWithSecret:secret oneTimePassword:@"pw"];
  a = [FIRTOTPMultiFactorGenerator assertionForSignInWithEnrollmentID:@"id" oneTimePassword:@"pw"];
}
#endif

- (void)FIRTwitterAuthProvider_h {
  __unused FIRAuthCredential *c = [FIRTwitterAuthProvider credentialWithToken:@"token"
                                                                       secret:@"secret"];
}

- (void)FIRUser_h:(FIRUser *)user credential:(FIRAuthCredential *)credential {
  [user updatePassword:@"pw"
            completion:^(NSError *_Nullable error){
            }];
  [user reloadWithCompletion:^(NSError *_Nullable error){
  }];
  [user reauthenticateWithCredential:credential
                          completion:^(FIRAuthDataResult *_Nullable authResult,
                                       NSError *_Nullable error){
                          }];
#if TARGET_OS_IOS
  FIRPhoneAuthProvider *provider = [FIRPhoneAuthProvider provider];
  FIRPhoneAuthCredential *phoneCredential = [provider credentialWithVerificationID:@"id"
                                                                  verificationCode:@"code"];
  [user updatePhoneNumberCredential:phoneCredential
                         completion:^(NSError *_Nullable error){
                         }];
  [user reauthenticateWithProvider:(NSObject<FIRFederatedAuthProvider> *)provider
                        UIDelegate:nil
                        completion:^(FIRAuthDataResult *_Nullable authResult,
                                     NSError *_Nullable error){
                        }];
  [user linkWithProvider:(NSObject<FIRFederatedAuthProvider> *)provider
              UIDelegate:nil
              completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
              }];
#endif
  [user getIDTokenResultWithCompletion:^(FIRAuthTokenResult *_Nullable tokenResult,
                                         NSError *_Nullable error){
  }];
  [user getIDTokenResultForcingRefresh:YES
                            completion:^(FIRAuthTokenResult *_Nullable tokenResult,
                                         NSError *_Nullable error){
                            }];
  [user getIDTokenWithCompletion:^(NSString *_Nullable token, NSError *_Nullable error){
  }];
  [user getIDTokenForcingRefresh:NO
                      completion:^(NSString *_Nullable token, NSError *_Nullable error){
                      }];
  [user linkWithCredential:credential
                completion:^(FIRAuthDataResult *_Nullable authResult, NSError *_Nullable error){
                }];
  [user unlinkFromProvider:@"provider"
                completion:^(FIRUser *_Nullable user, NSError *_Nullable error){
                }];
  [user sendEmailVerificationWithCompletion:^(NSError *_Nullable error){
  }];
  [user sendEmailVerificationBeforeUpdatingEmail:@"email"
                                      completion:^(NSError *_Nullable error){
                                      }];
  FIRActionCodeSettings *settings = [[FIRActionCodeSettings alloc] init];
  [user sendEmailVerificationWithActionCodeSettings:settings
                                         completion:^(NSError *_Nullable error){
                                         }];
  [user sendEmailVerificationBeforeUpdatingEmail:@"email"
                              actionCodeSettings:settings
                                      completion:^(NSError *_Nullable error){
                                      }];
  [user deleteWithCompletion:^(NSError *_Nullable error){
  }];
  FIRUserProfileChangeRequest *changeRequest = [user profileChangeRequest];
  [changeRequest commitChangesWithCompletion:^(NSError *_Nullable error){
  }];
  NSString *s = [user providerID];
  s = [user uid];
  s = [user displayName];
  s = [user email];
  s = [user phoneNumber];
  s = [changeRequest displayName];
  NSURL *u = [changeRequest photoURL];
  u = [user photoURL];
  [changeRequest setDisplayName:s];
  [changeRequest setPhotoURL:u];
}

- (void)userProperties:(FIRUser *)user {
  BOOL b = [user isAnonymous];
  b = [user isEmailVerified];
  __unused NSArray<NSObject<FIRUserInfo> *> *userInfo = [user providerData];
  __unused FIRUserMetadata *meta = [user metadata];
#if TARGET_OS_IOS
  __unused FIRMultiFactor *mf = [user multiFactor];
#endif
  NSString *s = [user refreshToken];
  s = [user tenantID];

  FIRUserProfileChangeRequest *changeRequest = [user profileChangeRequest];
  s = [changeRequest displayName];
  NSURL *u = [changeRequest photoURL];
  [changeRequest setDisplayName:s];
  [changeRequest setPhotoURL:u];
}

- (void)userInfoProperties:(NSObject<FIRUserInfo> *)userInfo {
  NSString *s = [userInfo providerID];
  s = [userInfo uid];
  s = [userInfo displayName];
  s = [userInfo email];
  s = [userInfo phoneNumber];
  __unused NSURL *u = [userInfo photoURL];
}

- (void)userMetadataProperties:(FIRUserMetadata *)metadata {
  NSDate *d = [metadata lastSignInDate];
  d = [metadata creationDate];
}

@end
