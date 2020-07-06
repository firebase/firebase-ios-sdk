// Copyright 2017 Google
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

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

#import "FirebaseCore/Sources/Private/FIROptionsInternal.h"

NSString *const kAndroidClientID = @"correct_android_client_id";
NSString *const kAPIKey = @"correct_api_key";
NSString *const kCustomizedAPIKey = @"customized_api_key";
NSString *const kClientID = @"correct_client_id";
NSString *const kTrackingID = @"correct_tracking_id";
NSString *const kGCMSenderID = @"correct_gcm_sender_id";
NSString *const kGoogleAppID = @"1:123:ios:123abc";
NSString *const kDatabaseURL = @"https://abc-xyz-123.firebaseio.com";
NSString *const kStorageBucket = @"project-id-123.storage.firebase.com";

NSString *const kDeepLinkURLScheme = @"comgoogledeeplinkurl";
NSString *const kNewDeepLinkURLScheme = @"newdeeplinkurlfortest";

NSString *const kBundleID = @"com.google.FirebaseSDKTests";
NSString *const kProjectID = @"abc-xyz-123";

@interface FIRTestCase ()

@end

@implementation FIRTestCase

- (void)setUp {
  [super setUp];
}

// Swift Package manager does not allow a test project to override a bundle in an app (or library).
- (void)mockFIROptions {
  // Keys for the strings in the plist file.
  NSString *const kFIRAPIKey = @"API_KEY";
  NSString *const kFIRTrackingID = @"TRACKING_ID";
  NSString *const kFIRGoogleAppID = @"GOOGLE_APP_ID";
  NSString *const kFIRClientID = @"CLIENT_ID";
  NSString *const kFIRGCMSenderID = @"GCM_SENDER_ID";
  NSString *const kFIRDatabaseURL = @"DATABASE_URL";
  NSString *const kFIRStorageBucket = @"STORAGE_BUCKET";
  NSString *const kFIRBundleID = @"BUNDLE_ID";
  NSString *const kFIRProjectID = @"PROJECT_ID";

  NSDictionary<NSString *, NSString *> *mockDictionary = @{
    kFIRAPIKey : kAPIKey,
    kFIRBundleID : kBundleID,
    kFIRClientID : kClientID,
    kFIRDatabaseURL : kDatabaseURL,
    kFIRGCMSenderID : kGCMSenderID,
    kFIRGoogleAppID : kGoogleAppID,
    kFIRProjectID : kProjectID,
    kFIRStorageBucket : kStorageBucket,
    kFIRTrackingID : kTrackingID,
  };
  id optionsClassMock = OCMClassMock([FIROptions class]);
  OCMStub([optionsClassMock defaultOptionsDictionary]).andReturn(mockDictionary);
}

- (void)tearDown {
  [super tearDown];
}

@end
