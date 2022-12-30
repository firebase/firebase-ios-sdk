/*
* Copyright 2020 Google LLC
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

import Foundation

/*
 Some of the Auth Credentials needs to be populated for the SwiftApiTests to work.

 Please follow the following steps to populate the valid AuthCredentials
 and copy it to Credentials.swift file

 You will need to replace the following values:

 $KGOOGLE_CLIENT_ID
 Get the value of the CLIENT_ID key in the GoogleService-Info.plist file..

 $KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN
 GOOGLE_TEST_ACCOUNT_REFRESH_TOKEN is the Google SignIn refresh token obtained for the Google client
 ID, saved for continuous tests.

 $KGOOGLE_USER_NAME
 The name of the test user for Google SignIn.

 $KFACEBOOK_APP_ID
 FACEBOOK_APP_ID is the developer's Facebook app's ID, to be used to test the
 'Signing in with Facebook' feature of Firebase Auth. Follow the instructions
 on the Facebook developer site: https://developers.facebook.com/docs/apps/register
 to obtain such an id.

 $KFACEBOOK_APP_ACCESS_TOKEN
 Once you have an Facebook App Id, click on dashboard from your app you can see
 both your App ID and the App Secret. Once you have both of these generate the
 access token using the step 13 of https://smashballoon.com/custom-facebook-feed/access-token/
 Follow the same link for comprehensive information on how to get the access token.

 $KFACEBOOK_USER_NAME
 The name of the test user for Facebook Login.
 */

class Credentials {
  static let kGoogleClientID =
    "636990941390-comoffgboe1r5kk0t6ttp7k3dhs1coal.apps.googleusercontent.com"
  static let kGoogleTestAccountRefreshToken = "1/134hwdX7aAj8sskH0DUOtyj-3czoeH1htMUqJHaBb9w"
  static let kGoogleUserName = "apitests ios"
  static let kFacebookAppID = "452491954956225"
  static let kFacebookAppAccessToken = "452491954956225|SWJY2EPl38uKLp-luKMSsGUvP4c"
  static let kFacebookUserName = "Michael Test"
}
