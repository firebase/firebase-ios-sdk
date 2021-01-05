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

#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenDeleteOperation.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingTokenOperation.h"

@implementation FIRMessagingTokenDeleteOperation

- (instancetype)initWithAuthorizedEntity:(NSString *)authorizedEntity
                                   scope:(NSString *)scope
                      checkinPreferences:(FIRMessagingCheckinPreferences *)checkinPreferences
                              instanceID:(NSString *)instanceID
                                  action:(FIRMessagingTokenAction)action {
  return [super initWithAction:action
           forAuthorizedEntity:authorizedEntity
                         scope:scope
                       options:nil
            checkinPreferences:checkinPreferences
                    instanceID:instanceID];
}

- (void)performTokenOperation {
  NSMutableURLRequest *request = [self tokenRequest];

  // Build form-encoded body
  NSString *deviceAuthID = self.checkinPreferences.deviceID;
  NSMutableArray<NSURLQueryItem *> *queryItems =
      [FIRMessagingTokenOperation standardQueryItemsWithDeviceID:deviceAuthID scope:self.scope];
  [queryItems addObject:[NSURLQueryItem queryItemWithName:@"delete" value:@"true"]];
  if (self.action == FIRMessagingTokenActionDeleteTokenAndIID) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"iid-operation" value:@"delete"]];
  }
  if (self.authorizedEntity) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:@"sender" value:self.authorizedEntity]];
  }
  // Typically we include our public key-signed url items, but in some cases (like deleting all FCM
  // tokens), we don't.
  if (self.instanceID.length > 0) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:kFIRMessagingParamInstanceID
                                                      value:self.instanceID]];
  }

  NSURLComponents *components = [[NSURLComponents alloc] init];
  components.queryItems = queryItems;
  NSString *content = components.query;
  request.HTTPBody = [content dataUsingEncoding:NSUTF8StringEncoding];
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenDeleteOperationFetchRequest,
                          @"Unregister request to %@ content: %@",
                          FIRMessagingTokenRegisterServer(), content);

  FIRMessaging_WEAKIFY(self);
  void (^requestHandler)(NSData *, NSURLResponse *, NSError *) =
      ^(NSData *data, NSURLResponse *response, NSError *error) {
        FIRMessaging_STRONGIFY(self);
        [self handleResponseWithData:data response:response error:error];
      };

  NSURLSessionConfiguration *config = NSURLSessionConfiguration.defaultSessionConfiguration;
  config.timeoutIntervalForResource = 60.0f;  // 1 minute
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
  self.dataTask = [session dataTaskWithRequest:request completionHandler:requestHandler];
  [self.dataTask resume];
}

- (void)handleResponseWithData:(NSData *)data
                      response:(NSURLResponse *)response
                         error:(NSError *)error {
  if (error) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenDeleteOperationRequestError,
                            @"Device unregister HTTP fetch error. Error code: %ld",
                            (long)error.code);
    [self finishWithResult:FIRMessagingTokenOperationError token:nil error:error];
    return;
  }

  NSString *dataResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (dataResponse.length == 0) {
    NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                       failureReason:@"Empty response."];
    [self finishWithResult:FIRMessagingTokenOperationError token:nil error:error];
    return;
  }

  if (![dataResponse hasPrefix:@"deleted="] && ![dataResponse hasPrefix:@"token="]) {
    NSString *failureReason =
        [NSString stringWithFormat:@"Invalid unregister response %@", response];
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTokenDeleteOperationBadResponse, @"%@",
                            failureReason);
    NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                       failureReason:failureReason];
    [self finishWithResult:FIRMessagingTokenOperationError token:nil error:error];
    return;
  }
  [self finishWithResult:FIRMessagingTokenOperationSucceeded token:nil error:nil];
}

@end
