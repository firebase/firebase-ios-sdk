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

#import <XCTest/XCTest.h>

@import FirebaseAuth;

#import "FIRAuthApiTestsBase.h"

/** Facebook app access token that will be used for Facebook Graph API, which is different from
 * account access token.
 */
static NSString *const kFacebookAppAccessToken = KFACEBOOK_APP_ACCESS_TOKEN;

/** Facebook app ID that will be used for Facebook Graph API. */
static NSString *const kFacebookAppID = KFACEBOOK_APP_ID;

static NSString *const kFacebookGraphApiAuthority = @"graph.facebook.com";

static NSString *const kFacebookTestAccountName = KFACEBOOK_USER_NAME;

@interface FacebookAuthTests : FIRAuthApiTestsBase

@end

@implementation FacebookAuthTests

// TODO(#10752) - Update and fix the Facebook login Sample app and tests.
- (void)SKIPtestSignInWithFacebook {
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
                  completion:^(FIRAuthDataResult *result, NSError *error) {
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
  [self deleteCurrentUser];
  [self deleteFacebookTestingAccountbyId:facebookAccountId];
}

// TODO(#10752) - Update and fix the Facebook login Sample app and tests.
- (void)SKIPtestLinkAnonymousAccountToFacebookAccount {
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
                            completion:^(FIRAuthDataResult *result, NSError *error) {
                              if (error) {
                                NSLog(@"Link to Facebook error: %@", error);
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
  [self deleteCurrentUser];
  [self deleteFacebookTestingAccountbyId:facebookAccountId];
}

/** Creates a Facebook testing account using Facebook Graph API and return a dictionary that
 * constains "id", "access_token", "login_url", "email" and "password" of the created account.
 */
- (NSDictionary *)createFacebookTestingAccount {
  // Build the URL.
  NSString *urltoCreateTestUser =
      [NSString stringWithFormat:@"https://%@/%@/accounts/test-users", kFacebookGraphApiAuthority,
                                 kFacebookAppID];
  // Build the POST request.
  NSString *bodyString =
      [NSString stringWithFormat:@"installed=true&name=%@&permissions=read_stream&access_token=%@",
                                 kFacebookTestAccountName, kFacebookAppAccessToken];
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
  // Parses the access token from the JSON data.
  NSDictionary *userInfoDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:nil];
  return userInfoDict;
}

/** Delete a Facebook testing account by account Id using Facebook Graph API. */
- (void)deleteFacebookTestingAccountbyId:(NSString *)accountId {
  // Build the URL.
  NSString *urltoDeleteTestUser =
      [NSString stringWithFormat:@"https://%@/%@", kFacebookGraphApiAuthority, accountId];

  // Build the POST request.
  NSString *bodyString =
      [NSString stringWithFormat:@"method=delete&access_token=%@", kFacebookAppAccessToken];
  NSData *postData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
  GTMSessionFetcherService *service = [[GTMSessionFetcherService alloc] init];
  GTMSessionFetcher *fetcher = [service fetcherWithURLString:urltoDeleteTestUser];
  fetcher.bodyData = postData;
  [fetcher setRequestValue:@"text/plain" forHTTPHeaderField:@"Content-Type"];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Deleting Facebook account finished."];
  [fetcher beginFetchWithCompletionHandler:^(NSData *receivedData, NSError *error) {
    NSString *deleteResult = [[NSString alloc] initWithData:receivedData
                                                   encoding:NSUTF8StringEncoding];
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

@end
