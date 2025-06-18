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

#import <OCMock/OCMock.h>

#import "FirebaseCore/Sources/Public/FirebaseCore/FIROptions.h"
#import "SharedTestUtilities/FIROptionsMock.h"

NSString *const kAPIKey = @"correct_api_key";
NSString *const kCustomizedAPIKey = @"customized_api_key";
NSString *const kClientID = @"correct_client_id";
NSString *const kGCMSenderID = @"correct_gcm_sender_id";
NSString *const kGoogleAppID = @"1:123:ios:123abc";
NSString *const kDatabaseURL = @"https://abc-xyz-123.firebaseio.com";
NSString *const kStorageBucket = @"project-id-123.storage.firebase.com";

NSString *const kBundleID = @"com.google.FirebaseSDKTests";
NSString *const kProjectID = @"abc-xyz-123";

/**
 * Keys for the strings in the plist file.
 */
extern NSString *const kFIRAPIKey;
extern NSString *const kFIRTrackingID;
extern NSString *const kFIRGoogleAppID;
extern NSString *const kFIRClientID;
extern NSString *const kFIRGCMSenderID;
extern NSString *const kFIRAndroidClientID;
extern NSString *const kFIRDatabaseURL;
extern NSString *const kFIRStorageBucket;
extern NSString *const kFIRBundleID;
extern NSString *const kFIRProjectID;

@interface FIROptions ()
+ (NSDictionary *)defaultOptionsDictionary;
@end

@interface FIROptionsMock ()

@end

@implementation FIROptionsMock

// Swift Package manager does not allow a test project to override a bundle in an app (or library).
+ (void)mockFIROptions {
  NSDictionary<NSString *, NSString *> *mockDictionary = @{
    kFIRAPIKey : kAPIKey,
    kFIRBundleID : kBundleID,
    kFIRClientID : kClientID,
    kFIRDatabaseURL : kDatabaseURL,
    kFIRGCMSenderID : kGCMSenderID,
    kFIRGoogleAppID : kGoogleAppID,
    kFIRProjectID : kProjectID,
    kFIRStorageBucket : kStorageBucket,
  };
  id optionsClassMock = OCMClassMock([FIROptions class]);
  OCMStub([optionsClassMock defaultOptionsDictionary]).andReturn(mockDictionary);
}

@end
