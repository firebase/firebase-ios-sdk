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
Some of the Auth Credentials needs to be populated for the ApiTests to work.

Please follow the following steps to populate the valid AuthCredentials
and copy it to AuthCredentials.h file

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

$KCUSTOM_AUTH_TOKEN_URL
A URL to return a Custom Auth token.

$KCUSTOM_AUTH_USER_ID
The ID of the test user in the Custom Auth token.
*/

#define KGOOGLE_CLIENT_ID $KGOOGLE_CLIENT_ID
#define KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN $KGOOGLE_TEST_ACCOUNT_REFRESH_TOKEN
#define KGOOGLE_USER_NAME $KGOOGLE_USER_NAME
#define KFACEBOOK_APP_ID $KFACEBOOK_APP_ID
#define KFACEBOOK_APP_ACCESS_TOKEN $KFACEBOOK_APP_ACCESS_TOKEN
#define KFACEBOOK_USER_NAME $KFACEBOOK_USER_NAME
#define KCUSTOM_AUTH_TOKEN_URL $KCUSTOM_AUTH_TOKEN_URL
#define KCUSTOM_AUTH_USER_ID $KCUSTOM_AUTH_USER_ID
