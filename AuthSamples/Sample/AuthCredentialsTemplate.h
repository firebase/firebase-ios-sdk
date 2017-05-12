/*
 * Copyright 2017 Google
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

/*
Some of the Auth Credentials needs to be populated for the Sample build to work.

Please follow the following steps to populate the valid AuthCredentials
and copy it to AuthCredentials.h file

You will need to replace the following values:
$KGOOGLE_CLIENT_ID
Get the value of the CLIENT_ID key in the GoogleService-Info.plist file..

$KFACEBOOK_APP_ID
FACEBOOK_APP_ID is the developer's Facebook app's ID, to be used to test the 
'Signing in with Facebook' feature of Firebase Auth. Follow the instructions 
on the Facebook developer site: https://developers.facebook.com/docs/apps/register 
to obtain such an id

$KAPP_ACCESS_TOKEN
Once you have an Facebook App Id, click on dashboard from your app you can see
both your App ID and the App Secret. Once you have both of these generate the 
access token using the step 13 of https://smashballoon.com/custom-facebook-feed/access-token/
Follow the same link for comprehensive information on how to get the access token.

$KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN
GOOGLE_TEST_ACCOUNT_REFRESH_TOKEN is the Google SignIn refresh token obtained for the Google client ID, 
saved for continuous tests.

The users that are behind these tokens must have user names as declared in the code, i.e., 
"John Test" for Google and "MichaelTest" for Facebook, or the FirebearApiTests will fail.
This can be found in ApiTests/FirebearApiTests.m with variable names kFacebookTestAccountName and
kGoogleTestAccountName

*/

#define KAPP_ACCESS_TOKEN $KAPP_ACCESS_TOKEN
#define KFACEBOOK_APP_ID $KFACEBOOK_APP_ID
#define KGOOGLE_CLIENT_ID $KGOOGLE_CLIENT_ID
#define KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN $KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN
