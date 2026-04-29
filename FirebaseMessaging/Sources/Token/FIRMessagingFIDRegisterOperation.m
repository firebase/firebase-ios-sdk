/*
 * Copyright 2026 Google
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

#import "FirebaseMessaging/Sources/Token/FIRMessagingFIDRegisterOperation.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FirebaseMessaging/Sources/FIRMessagingCode.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/FIRMessaging_Private.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Public/FirebaseMessaging/FIRMessaging.h"

@interface FIRMessagingTokenOperation (ExposedForSubclass)
- (void)setExecuting:(BOOL)executing;
@end

// Upon a network error or backend 5xx error, the request is retried this many times
// with exponential backoff.
static const int kMaxRetries = 10;

@interface FIRMessagingFIDRegisterOperation () {
  int _retryCount;
}
@property(nonatomic, strong) FIRInstallations *installations;
- (nullable NSString *)extractFIDFromHTTPResponse:(NSURLResponse *)response
                                             data:(NSData *)data
                                       forRequest:(NSURLRequest *)request
                                            error:(NSError **)outError;
@end

static BOOL isServerError(NSURLResponse *response) {
  if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    return httpResponse.statusCode >= 500 && httpResponse.statusCode < 600;
  }
  return NO;
}

@implementation FIRMessagingFIDRegisterOperation

- (instancetype)initWithAuthorizedEntity:(NSString *)authorizedEntity
                                   scope:(NSString *)scope
                                 options:(nullable NSDictionary<NSString *, NSString *> *)options
                              instanceID:(NSString *)instanceID
                         heartbeatLogger:(id<FIRHeartbeatLoggerProtocol>)heartbeatLogger
                           installations:(FIRInstallations *)installations {
  self = [super initWithAction:FIRMessagingTokenActionFetch
           forAuthorizedEntity:authorizedEntity
                         scope:scope
                       options:options
            checkinPreferences:nil
                    instanceID:instanceID
               heartbeatLogger:heartbeatLogger];
  if (self) {
    _installations = installations;
  }
  return self;
}

// Overriding start to bypass the checkin validation in the base class.
// The new FID registration API does not require checkin info, only the Installations auth token.
- (void)start {
  if (self.isCancelled) {
    [self finishWithResult:FIRMessagingTokenOperationCancelled token:nil error:nil];
    return;
  }

  [self setExecuting:YES];
  [self performTokenOperation];
}

- (void)performTokenOperation {
  FIRMessaging_WEAKIFY(self);
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        FIRMessaging_STRONGIFY(self);
        if (error) {
          FIRMessagingLoggerError(kFIRMessagingErrorCodeUnknown,
                                  @"Failed to get Installations auth token: %@", error);
          [self finishWithResult:FIRMessagingTokenOperationError token:nil error:error];
          return;
        }

        NSString *authToken = tokenResult.authToken;
        if (!authToken.length) {
          NSError *emptyTokenError =
              [NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                failureReason:@"Installations auth token is empty."];
          [self finishWithResult:FIRMessagingTokenOperationError token:nil error:emptyTokenError];
          return;
        }

        [self makeRegistrationRequestWithAuthToken:authToken];
      }];
}

- (void)makeRegistrationRequestWithAuthToken:(NSString *)authToken {
  FIROptions *options = FIRApp.defaultApp.options;
  NSString *projectID = options.projectID;
  NSString *apiKey = options.APIKey;

  if (!projectID.length || !apiKey.length) {
    NSError *missingInfoError = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                                  failureReason:@"Missing project ID or API key."];
    [self finishWithResult:FIRMessagingTokenOperationError token:nil error:missingInfoError];
    return;
  }

  NSString *urlString = [NSString
      stringWithFormat:@"https://fcmregistrations.googleapis.com/v1/projects/%@/registrations",
                       projectID];
  NSURL *url = [NSURL URLWithString:urlString];

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  request.HTTPMethod = @"POST";
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setValue:apiKey forHTTPHeaderField:@"X-Goog-Api-Key"];
  [request setValue:authToken forHTTPHeaderField:@"X-Goog-Firebase-Installations-Auth"];

  NSData *apnsToken = self.options[kFIRMessagingTokenOptionsAPNSKey];
  NSString *apnsTokenString = @"";
  if ([apnsToken isKindOfClass:[NSData class]]) {
    apnsTokenString = FIRMessagingStringForAPNSDeviceToken(apnsToken);
  } else {
    NSError *noTokenError = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeMissingDeviceToken
                                              failureReason:@"APNS token missing in options."];
    [self finishWithResult:FIRMessagingTokenOperationError token:nil error:noTokenError];
    return;
  }

  NSString *appVersion = FIRMessagingCurrentAppVersion();
  NSString *sdkVersion =
      [NSString stringWithFormat:@"fcm-%@", [FIRMessaging FIRMessagingSDKVersion]];

  BOOL isSandbox = [self.options[kFIRMessagingTokenOptionsAPNSIsSandboxKey] boolValue];
  NSString *apnsEnvironment = !isSandbox ? @"PROD" : @"SANDBOX";

  NSDictionary *body = @{
    @"ios" : @{
      @"apns_token" : apnsTokenString,
      @"app_version" : appVersion,
      @"apns_environment" : apnsEnvironment
    },
    @"fcm_sdk_version" : sdkVersion
  };

  NSError *jsonError;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
  if (jsonError) {
    [self finishWithResult:FIRMessagingTokenOperationError token:nil error:jsonError];
    return;
  }
  request.HTTPBody = jsonData;

  NSString *bodyString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeDebug,
                          @"FCM FID Registration Request to %@ Body: %@", urlString, bodyString);

  NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

  FIRMessaging_WEAKIFY(self);
  self.dataTask = [session
      dataTaskWithRequest:request
        completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                            NSError *_Nullable error) {
          FIRMessaging_STRONGIFY(self);
          // Retry on network error or backend server 5xx error.
          if ((error || isServerError(response)) && self->_retryCount < kMaxRetries) {
            const int nextRetryInterval = 1 << self->_retryCount;
            FIRMessaging_WEAKIFY(self);
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(nextRetryInterval * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                  FIRMessaging_STRONGIFY(self);
                  self->_retryCount++;
                  [self makeRegistrationRequestWithAuthToken:authToken];
                });
            return;
          }

          if (error) {
            [self finishWithResult:FIRMessagingTokenOperationError token:nil error:error];
            return;
          }

          NSError *extractionError;
          NSString *fid = [self extractFIDFromHTTPResponse:response
                                                      data:data
                                                forRequest:request
                                                     error:&extractionError];
          if (extractionError) {
            [self finishWithResult:FIRMessagingTokenOperationError token:nil error:extractionError];
            return;
          }

          [self finishWithResult:FIRMessagingTokenOperationSucceeded token:fid error:nil];
        }];
  [self.dataTask resume];
}

- (nullable NSString *)extractFIDFromHTTPResponse:(NSURLResponse *)response
                                             data:(NSData *)data
                                       forRequest:(NSURLRequest *)request
                                            error:(NSError **)outError {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  FIRMessagingLoggerDebug(
      kFIRMessagingMessageCodeDebug, @"FCM FID Registration Response from %@ (Status %ld): %@",
      request.URL.absoluteString, (long)httpResponse.statusCode, responseString);

  if (httpResponse.statusCode != 200 && httpResponse.statusCode != 201) {
    if (outError) {
      *outError = [NSError
          messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                   failureReason:[NSString stringWithFormat:@"Server returned status code %ld: %@",
                                                            (long)httpResponse.statusCode,
                                                            responseString]];
    }
    return nil;
  }

  NSError *parseError;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:&parseError];
  if (parseError) {
    if (outError) *outError = parseError;
    return nil;
  }

  // The response body looks like: {"name": "projects/<project_id>/registrations/<fid>", ...}
  NSString *name = responseDict[@"name"];
  NSString *fid = nil;
  if (name.length) {
    NSRange range = [name rangeOfString:@"/registrations/"];
    if (range.location != NSNotFound) {
      fid = [name substringFromIndex:range.location + range.length];
    }
  }

  if (!fid.length) {
    if (outError) {
      *outError = [NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                    failureReason:@"Failed to extract FID from response."];
    }
  }
  return fid;
}

@end
