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

#import <Foundation/Foundation.h>

#import "MainViewController.h"

@import FirebaseAuth;
#import "UIViewController+Alerts.h"
#import "AuthProviders.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kSignedInAlertTitle = @"Signed In";

static NSString *const kSignInErrorAlertTitle = @"Sign-In Error";

/** @brief The request type for OOB action codes.
 */
typedef enum {
  /** No action code settings. */
  ActionCodeRequestTypeEmail,
  /** With continue URL but not handled in-app. */
  ActionCodeRequestTypeContinue,
  /** Handled in-app. */
  ActionCodeRequestTypeInApp,
} ActionCodeRequestType;

typedef void (^TextInputCompletionBlock)(NSString *_Nullable userInput);

typedef void (^TestAutomationCallback)(NSError *_Nullable error);

@interface MainViewController ()

@property(nonatomic) BOOL isNewUserToggleOn;

@property(nonatomic) ActionCodeRequestType actionCodeRequestType;

@property(nonatomic) NSURL *actionCodeContinueURL;

@property(nonatomic, copy) NSString *appleRawNonce;

@property(nonatomic) FIROAuthProvider *googleOAuthProvider;
@property(nonatomic) FIROAuthProvider *microsoftOAuthProvider;
@property(nonatomic) FIROAuthProvider *twitterOAuthProvider;
@property(nonatomic) FIROAuthProvider *linkedinOAuthProvider;
@property(nonatomic) FIROAuthProvider *yahooOAuthProvider;
@property(nonatomic) FIROAuthProvider *gitHubOAuthProvider;

@property(nonatomic) NSMutableArray<FIRAuthStateDidChangeListenerHandle> *authStateDidChangeListeners;

@property(nonatomic) NSMutableArray<FIRAuthStateDidChangeListenerHandle> *IDTokenDidChangeListeners;

- (void)updateTable;

- (FIRUser *)user;

- (void)signinWithProvider:(id<AuthProvider>)authProvider retrieveData:(BOOL)retrieveData;

- (void)signInWithProvider:(nonnull id<AuthProvider>)provider callback:(void(^)(void))callback;

- (void)linkWithAuthProvider:(id<AuthProvider>)authProvider retrieveData:(BOOL)retrieveData;

- (void)unlinkFromProvider:(NSString *)provider
                completion:(nullable TestAutomationCallback)completion;

- (void)reauthenticate:(id<AuthProvider>)authProvider retrieveData:(BOOL)retrieveData;

- (void)log:(NSString *)string;

- (void)logSuccess:(NSString *)string;

- (void)logFailure:(NSString *)string error:(NSError * _Nullable) error;

- (void)logFailedTest:(NSString *)reason;

- (NSString *)stringWithAdditionalUserInfo:(nullable FIRAdditionalUserInfo *)additionalUserInfo;

- (void)showTypicalUIForUserUpdateResultsWithTitle:(NSString *)resultsTitle
                                             error:(NSError  * _Nullable)error;

- (FIRActionCodeSettings *)actionCodeSettings;

@end

NS_ASSUME_NONNULL_END
