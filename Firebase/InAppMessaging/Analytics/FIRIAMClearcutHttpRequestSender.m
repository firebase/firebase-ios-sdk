/*
 * Copyright 2018 Google
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

#import <FirebaseCore/FIRLogger.h>

#import "FIRCore+InAppMessaging.h"
#import "FIRIAMClearcutHttpRequestSender.h"
#import "FIRIAMClearcutLogStorage.h"
#import "FIRIAMClientInfoFetcher.h"
#import "FIRIAMTimeFetcher.h"

@interface FIRIAMClearcutHttpRequestSender ()
@property(readonly, copy, nonatomic) NSString *serverHostName;

@property(readwrite, nonatomic) id<FIRIAMTimeFetcher> timeFetcher;
@property(readonly, copy, nonatomic) NSString *osMajorVersion;
@end

@implementation FIRIAMClearcutHttpRequestSender

- (instancetype)initWithClearcutHost:(NSString *)serverHost
                    usingTimeFetcher:(id<FIRIAMTimeFetcher>)timeFetcher
                  withOSMajorVersion:(NSString *)osMajorVersion {
  if (self = [super init]) {
    _serverHostName = [serverHost copy];
    _timeFetcher = timeFetcher;
    _osMajorVersion = [osMajorVersion copy];
  }
  return self;
}

- (void)updateRequestBodyWithClearcutEnvelopeFields:(NSMutableDictionary *)bodyDict {
  bodyDict[@"client_info"] = @{
    @"client_type" : @15,  // 15 is the enum value for IOS_FIREBASE client
    @"ios_client_info" : @{@"os_major_version" : self.osMajorVersion ?: @""}
  };
  bodyDict[@"log_source"] = @"FIREBASE_INAPPMESSAGING";

  NSTimeInterval nowInMs = [self.timeFetcher currentTimestampInSeconds] * 1000;
  bodyDict[@"request_time_ms"] = @((long)nowInMs);
}

- (NSArray<NSDictionary *> *)constructLogEventsArrayLogRecords:
    (NSArray<FIRIAMClearcutLogRecord *> *)logRecords {
  NSMutableArray<NSDictionary *> *logEvents = [[NSMutableArray alloc] init];
  for (id next in logRecords) {
    FIRIAMClearcutLogRecord *logRecord = (FIRIAMClearcutLogRecord *)next;
    [logEvents addObject:@{
      @"event_time_ms" : @((long)logRecord.eventTimestampInSeconds * 1000),
      @"source_extension_json" : logRecord.eventExtensionJsonString ?: @""
    }];
  }

  return [logEvents copy];
}

// @return nil if error happened in constructing the body
- (NSDictionary *)constructRequestBodyWithRetryRecords:
    (NSArray<FIRIAMClearcutLogRecord *> *)logRecords {
  NSMutableDictionary *body = [[NSMutableDictionary alloc] init];
  [self updateRequestBodyWithClearcutEnvelopeFields:body];
  body[@"log_event"] = [self constructLogEventsArrayLogRecords:logRecords];
  return [body copy];
}

// a helper method for dealing with the response received from
// executing NSURLSessionDataTask. Triggers the completion callback accordingly
- (void)handleClearcutAPICallResponseWithData:(NSData *)data
                                     response:(NSURLResponse *)response
                                        error:(NSError *)error
                                   completion:
                                       (nonnull void (^)(BOOL success,
                                                         BOOL shouldRetryLogs,
                                                         int64_t waitTimeInMills))completion {
  if (error) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250003",
                  @"Internal error: encountered error in uploading clearcut message"
                   ":%@",
                  error);
    completion(NO, YES, 0);
    return;
  }

  if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250008",
                  @"Received non http response from sending "
                   "clearcut requests %@",
                  response);
    completion(NO, YES, 0);
    return;
  }

  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  if (httpResponse.statusCode == 200) {
    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM250004",
                @"Sending clearcut logging request was successful");

    NSError *errorJson = nil;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:kNilOptions
                                                                   error:&errorJson];

    int64_t waitTimeFromClearcutServer = 0;
    if (!errorJson && responseDict[@"next_request_wait_millis"]) {
      waitTimeFromClearcutServer = [responseDict[@"next_request_wait_millis"] longLongValue];
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM250007",
                  @"Wait time from clearcut server response is %d seconds",
                  (int)waitTimeFromClearcutServer / 1000);
    }
    completion(YES, NO, waitTimeFromClearcutServer);
  } else if (httpResponse.statusCode == 400) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250012",
                  @"Seeing 400 status code in response and we are discarding this log"
                  @"record");
    // 400 means bad request data and it won't be successful with retries. So
    // we give up on these log records
    completion(NO, NO, 0);
  } else {
    // May need to handle 401 errors if we do authentication in the future
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250005",
                  @"Other http status code seen in clearcut request response %d",
                  (int)httpResponse.statusCode);
    // can be retried
    completion(NO, YES, 0);
  }
}

- (void)sendClearcutHttpRequestForLogs:(NSArray<FIRIAMClearcutLogRecord *> *)logs
                        withCompletion:(nonnull void (^)(BOOL success,
                                                         BOOL shouldRetryLogs,
                                                         int64_t waitTimeInMills))completion {
  NSDictionary *requestBody = [self constructRequestBodyWithRetryRecords:logs];

  if (!requestBody) {
    FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250014",
                  @"Not able to construct request body for clearcut request, giving up");
    completion(NO, NO, 0);
  } else {
    // sending the log via a http request
    NSURLSession *URLSession = [NSURLSession sharedSession];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"POST"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];

    FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM250001",
                @"Request body dictionary is %@ for clearcut logging request", requestBody);

    NSError *error;
    NSData *requestBodyData = [NSJSONSerialization dataWithJSONObject:requestBody
                                                              options:0
                                                                error:&error];

    if (error) {
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250011",
                    @"Error in creating request body json for clearcut requests:%@", error);
      completion(NO, NO, 0);
      return;
    }

    NSString *requestURLString =
        [NSString stringWithFormat:@"https://%@/log?format=json_proto", self.serverHostName];
    [request setURL:[NSURL URLWithString:requestURLString]];
    [request setHTTPBody:requestBodyData];

    NSURLSessionDataTask *clearCutLogDataTask =
        [URLSession dataTaskWithRequest:request
                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                        [self handleClearcutAPICallResponseWithData:data
                                                           response:response
                                                              error:error
                                                         completion:completion];
                      }];

    if (clearCutLogDataTask == nil) {
      NSString *errorDesc = @"Internal error: NSURLSessionDataTask failed to be created due to "
                             "possibly incorrect parameters";
      FIRLogWarning(kFIRLoggerInAppMessaging, @"I-IAM250005", @"%@", errorDesc);
      completion(NO, NO, 0);
    } else {
      [clearCutLogDataTask resume];
      FIRLogDebug(kFIRLoggerInAppMessaging, @"I-IAM250002",
                  @"Making a restful api for sending clearcut logging data with "
                   "a NSURLSessionDataTask request as %@",
                  clearCutLogDataTask.currentRequest);
    }
  }
}
@end
