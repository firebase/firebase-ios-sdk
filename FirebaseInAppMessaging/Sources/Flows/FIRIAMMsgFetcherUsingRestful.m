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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseInAppMessaging/Sources/FIRCore+InAppMessaging.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMFetchResponseParser.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageContentDataWithImageURL.h"
#import "FirebaseInAppMessaging/Sources/Private/Data/FIRIAMMessageDefinition.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMMsgFetcherUsingRestful.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMFetchFlow.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMSDKSettings.h"

static NSInteger const SuccessHTTPStatusCode = 200;

@interface FIRIAMMsgFetcherUsingRestful ()
@property(readonly) NSURLSession *URLSession;
@property(readonly, copy, nonatomic) NSString *serverHostName;
@property(readonly, copy, nonatomic) NSString *appBundleID;
@property(readonly, copy, nonatomic) NSString *httpProtocol;
@property(readonly, copy, nonatomic) NSString *fbProjectNumber;
@property(readonly, copy, nonatomic) NSString *apiKey;
@property(readonly, copy, nonatomic) NSString *firebaseAppId;
@property(readonly, nonatomic) FIRIAMServerMsgFetchStorage *fetchStorage;
@property(readonly, nonatomic) FIRIAMClientInfoFetcher *clientInfoFetcher;
@property(readonly, nonatomic) FIRIAMFetchResponseParser *responseParser;
@end

@implementation FIRIAMMsgFetcherUsingRestful
- (instancetype)initWithHost:(NSString *)serverHost
                HTTPProtocol:(NSString *)HTTPProtocol
                     project:(NSString *)fbProjectNumber
                 firebaseApp:(NSString *)fbAppId
                      APIKey:(NSString *)apiKey
                fetchStorage:(FIRIAMServerMsgFetchStorage *)fetchStorage
           instanceIDFetcher:(FIRIAMClientInfoFetcher *)clientInfoFetcher
             usingURLSession:(nullable NSURLSession *)URLSession
              responseParser:(FIRIAMFetchResponseParser *)responseParser {
  if (self = [super init]) {
    _URLSession = URLSession ? URLSession : [NSURLSession sharedSession];
    _serverHostName = [serverHost copy];
    _fbProjectNumber = [fbProjectNumber copy];
    _firebaseAppId = [fbAppId copy];
    _httpProtocol = [HTTPProtocol copy];
    _apiKey = [apiKey copy];
    _clientInfoFetcher = clientInfoFetcher;
    _fetchStorage = fetchStorage;
    _appBundleID = [NSBundle mainBundle].bundleIdentifier;
    _responseParser = responseParser;
  }
  return self;
}

- (void)updatePostFetchData:(NSMutableDictionary *)postData
         withImpressionList:(NSArray<FIRIAMImpressionRecord *> *)impressionList
           instanceIDString:(nonnull NSString *)IIDValue
                   IIDToken:(nonnull NSString *)IIDToken {
  NSMutableArray *impressionListForPost = [[NSMutableArray alloc] init];
  for (FIRIAMImpressionRecord *nextImpressionRecord in impressionList) {
    NSDictionary *nextImpression = @{
      @"campaign_id" : nextImpressionRecord.messageID,
      @"impression_timestamp_millis" : @(nextImpressionRecord.impressionTimeInSeconds * 1000)
    };
    [impressionListForPost addObject:nextImpression];
  }
  [postData setObject:impressionListForPost forKey:@"already_seen_campaigns"];

  if (IIDValue) {
    NSDictionary *clientAppInfo = @{
      @"gmp_app_id" : self.firebaseAppId,
      @"app_instance_id" : IIDValue,
      @"app_instance_id_token" : IIDToken
    };
    [postData setObject:clientAppInfo forKey:@"requesting_client_app"];
  }

  NSMutableArray *clientSignals = [@{} mutableCopy];

  // set client signal fields only when they are present
  if ([self.clientInfoFetcher getAppVersion]) {
    [clientSignals setValue:[self.clientInfoFetcher getAppVersion] forKey:@"app_version"];
  }

  if ([self.clientInfoFetcher getOSVersion]) {
    [clientSignals setValue:[self.clientInfoFetcher getOSVersion] forKey:@"platform_version"];
  }

  if ([self.clientInfoFetcher getDeviceLanguageCode]) {
    [clientSignals setValue:[self.clientInfoFetcher getDeviceLanguageCode] forKey:@"language_code"];
  }

  if ([self.clientInfoFetcher getTimezone]) {
    [clientSignals setValue:[self.clientInfoFetcher getTimezone] forKey:@"time_zone"];
  }

  [postData setObject:clientSignals forKey:@"client_signals"];
}

- (void)fetchMessagesWithImpressionList:(NSArray<FIRIAMImpressionRecord *> *)impressonList
                           withIIDvalue:(NSString *)iidValue
                               IIDToken:(NSString *)iidToken
                             completion:(FIRIAMFetchMessageCompletionHandler)completion {
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
  [request setHTTPMethod:@"POST"];

  if (_appBundleID.length) {
    // Handle the case in which the API key is being restricted to specific iOS app bundle,
    // which can be set on Google Cloud console side for API key credentials.
    [request addValue:_appBundleID forHTTPHeaderField:@"X-Ios-Bundle-Identifier"];
  }

  [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
  [request addValue:iidToken forHTTPHeaderField:@"x-goog-firebase-installations-auth"];

  NSMutableDictionary *postFetchDict = [[NSMutableDictionary alloc] init];
  [self updatePostFetchData:postFetchDict
         withImpressionList:impressonList
           instanceIDString:iidValue
                   IIDToken:iidToken];

  NSData *postFetchData = [NSJSONSerialization dataWithJSONObject:postFetchDict
                                                          options:0
                                                            error:nil];

  NSString *requestURLString = [NSString
      stringWithFormat:@"%@://%@/v1/sdkServing/projects/%@/eligibleCampaigns:fetch?key=%@",
                       self.httpProtocol, self.serverHostName, self.fbProjectNumber, self.apiKey];
  [request setURL:[NSURL URLWithString:requestURLString]];
  [request setHTTPBody:postFetchData];

  FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM130001",
              @"Making a restful API request for pulling messages with fetch POST body as %@ "
               "and request headers as %@",
              postFetchDict, request.allHTTPHeaderFields);

  NSURLSessionDataTask *postDataTask = [self.URLSession
      dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
          if (error) {
            FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130002",
                          @"Internal error: encountered error in pulling messages from server"
                           ":%@",
                          error);
            completion(nil, nil, 0, error);
          } else {
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
              if (httpResponse.statusCode == SuccessHTTPStatusCode) {
                // got response data successfully
                FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM130007",
                            @"Fetch API response headers are %@", [httpResponse allHeaderFields]);

                NSError *errorJson = nil;
                NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                                             options:kNilOptions
                                                                               error:&errorJson];
                if (errorJson) {
                  FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130003",
                                @"Failed to parse the response body as JSON string %@", errorJson);
                  completion(nil, nil, 0, errorJson);
                } else {
                  NSInteger discardCount;
                  NSNumber *nextFetchWaitTimeFromResponse;
                  NSArray<FIRIAMMessageDefinition *> *messages = [self.responseParser
                      parseAPIResponseDictionary:responseDict
                               discardedMsgCount:&discardCount
                          fetchWaitTimeInSeconds:&nextFetchWaitTimeFromResponse];

                  if (messages) {
                    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM130012",
                                @"API request for fetching messages and parsing the response was "
                                 "successful.");

                    [self.fetchStorage
                        saveResponseDictionary:responseDict
                                withCompletion:^(BOOL success) {
                                  if (!success)
                                    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130010",
                                                  @"Failed to persist server fetch response");
                                }];
                    // always report success regardless of whether we are able to persist into
                    // storage. they should get fixed in the next fetch cycle if it happens.
                    completion(messages, nextFetchWaitTimeFromResponse, discardCount, nil);
                  } else {
                    NSString *errorDesc =
                        @"Failed to recognize the fiam messages in the server response";
                    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130011", @"%@", errorDesc);
                    NSError *error =
                        [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                                            code:0
                                        userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
                    completion(nil, nil, 0, error);
                  }
                }
              } else {
                NSString *responseBody = [[NSString alloc] initWithData:data
                                                               encoding:NSUTF8StringEncoding];

                FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130004",
                              @"Failed restful api request to fetch in-app messages: seeing http "
                              @"status code as %ld with body as %@",
                              (long)httpResponse.statusCode, responseBody);

                NSError *error = [NSError errorWithDomain:NSURLErrorDomain
                                                     code:httpResponse.statusCode
                                                 userInfo:nil];
                completion(nil, nil, 0, error);
              }
            } else {
              NSString *errorDesc = @"Got a non http response type from fetch endpoint";
              FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130005", @"%@", errorDesc);

              NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                                                   code:0
                                               userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
              completion(nil, nil, 0, error);
            }
          }
        }];

  if (postDataTask == nil) {
    NSString *errorDesc =
        @"Internal error: NSURLSessionDataTask failed to be created due to possibly "
         "incorrect parameters";
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM130006", @"%@", errorDesc);
    NSError *error = [NSError errorWithDomain:kFirebaseInAppMessagingErrorDomain
                                         code:0
                                     userInfo:@{NSLocalizedDescriptionKey : errorDesc}];
    completion(nil, nil, 0, error);
  } else {
    [postDataTask resume];
  }
}

#pragma mark - protocol FIRIAMMessageFetcher
- (void)fetchMessagesWithImpressionList:(NSArray<FIRIAMImpressionRecord *> *)impressonList
                         withCompletion:(FIRIAMFetchMessageCompletionHandler)completion {
  // First step is to fetch the instance id value and token on the fly. We are not caching the data
  // since the fetch operation frequency is low enough that we are not concerned about its impact
  // on server load and this guarantees that we always have an up-to-date iid values and tokens.
  [self.clientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:self.fbProjectNumber
                                      withCompletion:^(NSString *_Nullable FID,
                                                       NSString *_Nullable FISToken,
                                                       NSError *_Nullable error) {
                                        if (error) {
                                          FIRLogWarning(
                                              kFIRLoggerInAppMessaging, @"I-IAM130008",
                                              @"Not able to get iid value and/or token for "
                                              @"talking to server: %@",
                                              error.localizedDescription);
                                          completion(nil, nil, 0, error);
                                        } else {
                                          [self fetchMessagesWithImpressionList:impressonList
                                                                   withIIDvalue:FID
                                                                       IIDToken:FISToken
                                                                     completion:completion];
                                        }
                                      }];
}
@end

#endif  // TARGET_OS_IOS
