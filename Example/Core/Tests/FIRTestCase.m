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

#import "FIRTestCase.h"

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

- (void)tearDown {
  [super tearDown];
}

@end
