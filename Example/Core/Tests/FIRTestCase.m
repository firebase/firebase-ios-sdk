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

#import <asl.h>

extern aslclient getFIRLoggerClient(void);
extern const char *kFIRLoggerASLClientFacilityName;

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

#pragma mark - Helper Methods

- (BOOL)messageWasLogged:(NSString *)message {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  aslmsg query = asl_new(ASL_TYPE_QUERY);
  asl_set_query(query, ASL_KEY_FACILITY, kFIRLoggerASLClientFacilityName, ASL_QUERY_OP_EQUAL);
  aslresponse r = asl_search(getFIRLoggerClient(), query);
  asl_free(query);
  aslmsg m;
  const char *val;
  NSMutableArray *allMsg = [[NSMutableArray alloc] init];
  while ((m = asl_next(r)) != NULL) {
    val = asl_get(m, ASL_KEY_MSG);
    if (val) {
      [allMsg addObject:[NSString stringWithUTF8String:val]];
    }
  }
  asl_free(m);
  asl_release(r);
  return [allMsg containsObject:message];
#pragma clang pop
}

@end
