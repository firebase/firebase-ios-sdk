#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "googlemac/iPhone/Firebase/Source/FIRApp.h"
#import "googlemac/iPhone/Identity/Firebear/Auth/Source/FirebaseAuth.h"
#import "googlemac/iPhone/Shared/ioReplayer/IORManager.h"
#import "googlemac/iPhone/Shared/ioReplayer/IORTestCase.h"

#import "third_party/objective_c/gtm_session_fetcher/Source/GTMSessionFetcher.h"
#import "third_party/objective_c/gtm_session_fetcher/Source/GTMSessionFetcherService.h"

/** Facebook app access token that will be used for Facebook Graph API, which is different from
 * account access token.
 */
static NSString *const kAppAccessToken = @"452491954956225|gzz29mUXjbqq-vZWrDQ5U-c2t2s";

/** The user name string for BYOAuth testing account. */
static NSString *const kBYOAuthTestingAccountUserName = @"John GoogleSpeed";

/** The url for obtaining a valid custom token string used to test BYOAuth. */
static NSString *const kCustomTokenUrl = @"https://fb-sa-1211.appspot.com/token";

/** Facebook app ID that will be used for Facebook Graph API.
 * https://valentine.corp.google.com/#/show/1460636635365941?tab=metadata has the username and
 * password of the shared gmail account which creates this Facebook app.
 */
static NSString *const kFacebookAppID = @"452491954956225";

static NSString *const kFacebookGraphApiAuthority = @"graph.facebook.com";

static NSString *const kFacebookTestAccountName = @"MichaelTest";

static NSString *const kGoogleTestAccountName = @"John Test";

/** The invalid custom token string for testing BYOAuth. */
static NSString *const kInvalidCustomToken = @"invalid token.";

/** The testing email address for testCreateAccountWithEmailAndPassword. */
static NSString *const kTestingEmailToCreateUser = @"abc@xyz.com";

/** The testing email address for testSignInExistingUserWithEmailAndPassword. */
static NSString *const kExistingTestingEmailToSignIn = @"456@abc.com";

/** Error message for invalid custom token sign in. */
NSString *kInvalidTokenErrorMessage =
    @"The custom token format is incorrect. Please check the documentation.";

/** Cliend Id for Google sign in project "fb-sa-upgraded". Please be sync with the CLIENT_ID in
 * Firebear/Sample/GoogleService-Info.plist. */
NSString *kGoogleCliendId =
    @"1085102361755-pboq9vt0lrg5g7d28v4n4c88c051fqmv.apps.googleusercontent.com";

/** Refresh token of Google test account to exchange for access token. Refresh token never expires
 * unless user revokes it. If this refresh token expires, tests in record mode will fail and this
 * token needs to be updated. More details at
 * http://g3doc/company/teams/user-testing/identity/firebear/faq. */
NSString *kGoogleTestAccountRefreshToken = @"1/JflfOhyO4ldLlddTnoMdSKkTqxaLpd3-aBkyDhH5_wU";

static NSTimeInterval const kExpectationsTimeout = 10;

@interface ApiTests : IORTestCase
@end

@implementation ApiTests

/** To reset the app so that each test sees the app in a clean state. */
- (void)setUp {
  [super setUp];
  [self signOut];
}

#pragma mark - Tests

/**
 * This test runs in replay mode by default. To run in a different mode follow the instructions
 * below.
 *
 * Blaze: --test_arg=\'--networkReplayMode=(replay|record|disabled|observe)\'
 *
 * Xcode:
 * Update the following flag in the xcscheme.
 * --networkReplayMode=(replay|record|disabled|observe)
 */
- (void)testCreateAccountWithEmailAndPassword {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Created account with email and password."];
  [auth createUserWithEmail:kTestingEmailToCreateUser
                   password:@"password"
                 completion:^(FIRUser *user, NSError *error) {
                   if (error) {
                     NSLog(@"createUserWithEmail has error: %@", error);
                   }
                   [expectation fulfill];
                 }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in creating account. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertEqualObjects(auth.currentUser.email, kTestingEmailToCreateUser);

  // Clean up the created Firebase user for future runs.
  [self deleteCurrentFirebaseUser];
}

- (void)testLinkAnonymousAccountToFacebookAccount {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  [self signInAnonymously];

  NSDictionary *userInfoDict = [self createFacebookTestingAccount];
  NSString *facebookAccessToken = userInfoDict[@"access_token"];
  NSLog(@"Facebook testing account access token is: %@", facebookAccessToken);
  NSString *facebookAccountId = userInfoDict[@"id"];
  NSLog(@"Facebook testing account id is: %@", facebookAccountId);

  FIRAuthCredential *credential =
      [FIRFacebookAuthProvider credentialWithAccessToken:facebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"Facebook linking finished."];
  [auth.currentUser linkWithCredential:credential
                            completion:^(FIRUser *user, NSError *error) {
                              if (error) {
                                NSLog(@"Link to Facebok error: %@", error);
                              }
                              [expectation fulfill];
                            }];

  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in linking to Facebook. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
  NSArray<id<FIRUserInfo>> *providerData = auth.currentUser.providerData;
  XCTAssertEqual([providerData count], 1);
  XCTAssertEqualObjects([providerData[0] providerID], @"facebook.com");

  // Clean up the created Firebase/Facebook user for future runs.
  [self deleteCurrentFirebaseUser];
  [self deleteFacebookTestingAccountbyId:facebookAccountId];
}

- (void)testSignInAnonymously {
  [self signInAnonymously];
  XCTAssertTrue([FIRAuth auth].currentUser.anonymous);
  [self deleteCurrentFirebaseUser];
}

- (void)testSignInExistingUserWithEmailAndPassword {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Signed in existing account with email and password."];
  [auth signInWithEmail:kExistingTestingEmailToSignIn
               password:@"password"
             completion:^(FIRUser *user, NSError *error) {
               if (error) {
                 NSLog(@"Signing in existing account has error: %@", error);
               }
               [expectation fulfill];
             }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in signing in existing account. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertEqualObjects(auth.currentUser.email, kExistingTestingEmailToSignIn);
}

- (void)testSignInWithValidBYOAuthToken {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  NSError *error;
  NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
  if (!customToken) {
    XCTFail(@"There was an error retrieving the custom token: %@", error);
  }
  NSLog(@"The valid token is: %@", customToken);

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"BYOAuthToken sign-in finished."];

  [auth signInWithCustomToken:customToken
                   completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {
                     if (error) {
                       NSLog(@"Valid token sign in error: %@", error);
                     }
                     [expectation fulfill];
                   }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in BYOAuthToken sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];

  XCTAssertEqualObjects(auth.currentUser.displayName, kBYOAuthTestingAccountUserName);
}

- (void)testSignInWithInvalidBYOAuthToken {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Invalid BYOAuthToken sign-in finished."];

  [auth signInWithCustomToken:kInvalidCustomToken
                   completion:^(FIRUser *_Nullable user, NSError *_Nullable error) {

                     XCTAssertEqualObjects(error.localizedDescription, kInvalidTokenErrorMessage);
                     [expectation fulfill];
                   }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in BYOAuthToken sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

- (void)testSignInWithFaceboook {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  NSDictionary *userInfoDict = [self createFacebookTestingAccount];
  NSString *facebookAccessToken = userInfoDict[@"access_token"];
  NSLog(@"Facebook testing account access token is: %@", facebookAccessToken);
  NSString *facebookAccountId = userInfoDict[@"id"];
  NSLog(@"Facebook testing account id is: %@", facebookAccountId);

  FIRAuthCredential *credential =
      [FIRFacebookAuthProvider credentialWithAccessToken:facebookAccessToken];

  XCTestExpectation *expectation = [self expectationWithDescription:@"Facebook sign-in finished."];

  [auth signInWithCredential:credential
                  completion:^(FIRUser *user, NSError *error) {
                    if (error) {
                      NSLog(@"Facebook sign in error: %@", error);
                    }
                    [expectation fulfill];
                  }];

  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in Facebook sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
  XCTAssertEqualObjects(auth.currentUser.displayName, kFacebookTestAccountName);

  // Clean up the created Firebase/Facebook user for future runs.
  [self deleteCurrentFirebaseUser];
  [self deleteFacebookTestingAccountbyId:facebookAccountId];
}

- (void)testSignInWithGoogle {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  NSDictionary *userInfoDict = [self getGoogleAccessToken];
  NSString *googleAccessToken = userInfoDict[@"access_token"];
  NSString *googleIdToken = userInfoDict[@"id_token"];
  FIRAuthCredential *credential =
      [FIRGoogleAuthProvider credentialWithIDToken:googleIdToken accessToken:googleAccessToken];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Signing in with Google finished."];
  [auth signInWithCredential:credential
                  completion:^(FIRUser *user, NSError *error) {
                    if (error) {
                      NSLog(@"Signing in with Google had error: %@", error);
                    }
                    [expectation fulfill];
                  }];

  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in Signing in with Google. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
  XCTAssertEqualObjects(auth.currentUser.displayName, kGoogleTestAccountName);

  // Clean up the created Firebase/Facebook user for future runs.
  [self deleteCurrentFirebaseUser];
}

#pragma mark - Helpers

/** Sign out current account. */
- (void)signOut {
  NSError *signOutError;
  BOOL status = [[FIRAuth auth] signOut:&signOutError];

  // Just log the error because we don't want to fail the test if signing out
  // fails.
  if (!status) {
    NSLog(@"Error signing out: %@", signOutError);
  }
}

/** Creates a Facebook testing account using Facebook Graph API and return a dictionary that
 * constains "id", "access_token", "login_url", "email" and "password" of the created account. More
 * details at http://g3doc/company/teams/user-testing/identity/firebear/faq.
 */
- (NSDictionary *)createFacebookTestingAccount {
  // Build the URL.
  NSString *urltoCreateTestUser =
      [NSString stringWithFormat:@"https://%@/%@/accounts/test-users", kFacebookGraphApiAuthority,
                                 kFacebookAppID];
  // Build the POST request.
  NSString *bodyString =
      [NSString stringWithFormat:@"installed=true&name=%@&permissions=read_stream&access_token=%@",
                                 kFacebookTestAccountName, kAppAccessToken];
  NSData *postData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
  GTMSessionFetcherService *service = [[GTMSessionFetcherService alloc] init];
  GTMSessionFetcher *fetcher = [service fetcherWithURLString:urltoCreateTestUser];
  fetcher.bodyData = postData;
  [fetcher setRequestValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Creating Facebook account finished."];
  __block NSData *data = nil;
  [fetcher beginFetchWithCompletionHandler:^(NSData *receivedData, NSError *error) {
    if (error) {
      NSLog(@"Creating Facebook account finished with error: %@", error);
      return;
    }
    data = receivedData;
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in creating Facebook account. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
  NSString *userInfo = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSLog(@"The info of created Facebook testing account is: %@", userInfo);
  // Parses the access token from the JSON data.
  NSDictionary *userInfoDict =
      [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
  return userInfoDict;
}

/** Clean up the created user for tests' future runs. */
- (void)deleteCurrentFirebaseUser {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    NSLog(@"Could not obtain auth object.");
  }

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Delete current user finished."];
  [auth.currentUser deleteWithCompletion:^(NSError *_Nullable error) {
    if (error) {
      XCTFail(@"Failed to delete user. Error: %@.", error);
    }
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in deleting user. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

- (void)signInAnonymously {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Anonymousy sign-in finished."];
  [auth signInAnonymouslyWithCompletion:^(FIRUser *user, NSError *error) {
    if (error) {
      NSLog(@"Anonymousy sign in error: %@", error);
    }
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in anonymousy sign in. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

/** Delete a Facebook testing account by account Id using Facebook Graph API. */
- (void)deleteFacebookTestingAccountbyId:(NSString *)accountId {
  // Build the URL.
  NSString *urltoDeleteTestUser =
      [NSString stringWithFormat:@"https://%@/%@", kFacebookGraphApiAuthority, accountId];

  // Build the POST request.
  NSString *bodyString =
      [NSString stringWithFormat:@"method=delete&access_token=%@", kAppAccessToken];
  NSData *postData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
  GTMSessionFetcherService *service = [[GTMSessionFetcherService alloc] init];
  GTMSessionFetcher *fetcher = [service fetcherWithURLString:urltoDeleteTestUser];
  fetcher.bodyData = postData;
  [fetcher setRequestValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Deleting Facebook account finished."];
  [fetcher beginFetchWithCompletionHandler:^(NSData *receivedData, NSError *error) {
    NSString *deleteResult =
        [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSLog(@"The result of deleting Facebook account is: %@", deleteResult);
    if (error) {
      NSLog(@"Deleting Facebook account finished with error: %@", error);
    }
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in deleting Facebook account. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
}

/** Sends http request to Google OAuth2 token server to use refresh token to exchange for Google
 * access token. Returns a dictionary that constains "access_token", "token_type", "expires_in" and
 * "id_token".
 */
- (NSDictionary *)getGoogleAccessToken {
  NSString *googleOauth2TokenServerUrl = @"https://www.googleapis.com/oauth2/v4/token";
  NSString *bodyString =
      [NSString stringWithFormat:@"client_id=%@&grant_type=refresh_token&refresh_token=%@",
                                 kGoogleCliendId, kGoogleTestAccountRefreshToken];
  NSData *postData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
  GTMSessionFetcherService *service = [[GTMSessionFetcherService alloc] init];
  GTMSessionFetcher *fetcher = [service fetcherWithURLString:googleOauth2TokenServerUrl];
  fetcher.bodyData = postData;
  [fetcher setRequestValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Exchanging Google account tokens finished."];
  __block NSData *data = nil;
  [fetcher beginFetchWithCompletionHandler:^(NSData *receivedData, NSError *error) {
    if (error) {
      NSLog(@"Exchanging Google account tokens finished with error: %@", error);
      return;
    }
    data = receivedData;
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:kExpectationsTimeout
                               handler:^(NSError *error) {
                                 if (error != nil) {
                                   XCTFail(@"Failed to wait for expectations "
                                           @"in exchanging Google account tokens. Error: %@",
                                           error.localizedDescription);
                                 }
                               }];
  NSString *userInfo = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSLog(@"The info of exchanged result is: %@", userInfo);
  NSDictionary *userInfoDict =
      [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
  return userInfoDict;
}
@end
