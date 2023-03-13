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

static NSString *kGoogleClientID = KGOOGLE_CLIENT_ID;

static NSString *const kGoogleTestAccountName = KGOOGLE_USER_NAME;

/** Refresh token of Google test account to exchange for access token. Refresh token never expires
 * unless user revokes it. If this refresh token expires, tests in record mode will fail and this
 * token needs to be updated.
 */
NSString *kGoogleTestAccountRefreshToken = KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN;

@interface GoogleAuthTests : FIRAuthApiTestsBase

@end

@implementation GoogleAuthTests

- (void)testSignInWithGoogle {
  FIRAuth *auth = [FIRAuth auth];
  if (!auth) {
    XCTFail(@"Could not obtain auth object.");
  }
  NSDictionary *userInfoDict = [self getGoogleAccessToken];
  NSString *googleAccessToken = userInfoDict[@"access_token"];
  NSString *googleIdToken = userInfoDict[@"id_token"];
  FIRAuthCredential *credential = [FIRGoogleAuthProvider credentialWithIDToken:googleIdToken
                                                                   accessToken:googleAccessToken];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Signing in with Google finished."];
  [auth signInWithCredential:credential
                  completion:^(FIRAuthDataResult *result, NSError *error) {
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

  if (auth.currentUser.displayName) {
    XCTAssertEqualObjects(auth.currentUser.displayName, kGoogleTestAccountName);
  }
}

/** Sends http request to Google OAuth2 token server to use refresh token to exchange for Google
 * access token. Returns a dictionary that constains "access_token", "token_type", "expires_in" and
 * sometimes the "id_token". (The id_token is not guaranteed to be returned during a refresh
 * exchange; see https://openid.net/specs/openid-connect-core-1_0.html#RefreshTokenResponse)
 */
- (NSDictionary *)getGoogleAccessToken {
  NSString *googleOauth2TokenServerUrl = @"https://www.googleapis.com/oauth2/v4/token";
  NSString *bodyString =
      [NSString stringWithFormat:@"client_id=%@&grant_type=refresh_token&refresh_token=%@",
                                 kGoogleClientID, kGoogleTestAccountRefreshToken];
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
  NSDictionary *userInfoDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:nil];
  return userInfoDict;
}

@end
