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

#import "FIRAuthTVService.h"

#import "FIRAuthTVCode.h"
#import "FIRAuthTVPollRequest.h"
#import "FIRAuthTVPollResult.h"

NSString * const kFIRAuthClientIDKey = @"client_id";
NSString * const kFIRAuthClientSecretKey = @"client_secret";
NSString * const kFIRAuthScopeKey = @"scope";
NSString * const kFIRAuthScope = @"email%20profile";

#warning Fill out the two following fields from the Cloud console.
NSString * const kFIRAuthTVClientID = @"FILL ME OUT";
NSString * const kFIRAuthTVClientSecret = @"FILL ME OUT";

@implementation FIRAuthTVService

- (void)requestAuthorizationCodeWithCompletion:(nonnull FIRAuthTVAuthorizationCallback)callback {
  NSURL *url = [NSURL URLWithString:@"https://accounts.google.com/o/oauth2/device/code"];
  NSURLRequest *request = [self postRequestWithURL:url
                                        parameters:@{
                                                     kFIRAuthClientIDKey: kFIRAuthTVClientID,
                                                     kFIRAuthScopeKey: kFIRAuthScope
                                                     }];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData * _Nullable data,
                                                              NSURLResponse * _Nullable response,
                                                              NSError * _Nullable error) {
    if (error) {
      NSLog(@"Error with data task: %@", error.localizedDescription);
      // TODO: Customize error.
      callback(nil, error);
      return;
    }

    if (!(data && response)) {
      // TODO: Customize error with proper fields.
      callback(nil, [NSError errorWithDomain:@"com.firebase.auth"
                                        code:1
                                    userInfo:@{ NSLocalizedDescriptionKey: @"Objective-C sucks" }]);
      return;
    }

    // Assume data and response are fine, because Obj-C.
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([httpResponse statusCode] == 200) {
      FIRAuthTVCode *code = [self tvCodeFromData:data];
      callback(code, nil);
    } else {
      NSLog(@"Something went wrong, status code: %ld", (long)[httpResponse statusCode]);
      // TODO: Return customized error.
      callback(nil, nil);
    }
  }];

  // Start the task.
  [task resume];
}

- (void)pollServersWithCode:(FIRAuthTVCode *)code
            successCallback:(void (^)(FIRAuthTVPollResult *))successCallback
            failureCallback:(void (^)(NSError *))failureCallback {
  // TODO: Check total timeout here as well. This is messy.
  NSURL *url = [NSURL URLWithString:@"https://www.googleapis.com/oauth2/v4/token"];
  FIRAuthTVPollRequest *pollRequest =
      [[FIRAuthTVPollRequest alloc] initWithClientID:kFIRAuthTVClientID
                                        clientSecret:kFIRAuthTVClientSecret
                                          deviceCode:code.deviceCode];
  NSURLRequest *request = [self postRequestWithURL:url
                                        parameters:[pollRequest generatedParameters]];
  NSURLSession *session = [NSURLSession sharedSession];
  NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData * _Nullable data,
                                                              NSURLResponse * _Nullable response,
                                                              NSError * _Nullable error) {
    if (error) {
      NSLog(@"Error polling server: %@",
            error.localizedDescription);
      // TODO: Customize error.
      failureCallback(error);
      return;
    }

    if (!(data && response)) {
      // TODO: Customize error with proper fields.
      failureCallback([NSError errorWithDomain:@"com.firebase.auth"
                                          code:1
                                      userInfo:@{ NSLocalizedDescriptionKey: @"Objective-C sucks" }]);
      return;
    }

    // Get the dictionary as it's needed to parse the response.
    NSError *parsingError = nil;
    NSDictionary *resultDictionary = [NSJSONSerialization JSONObjectWithData:data
                                                             options:0
                                                               error:&parsingError];
    if (parsingError) {
      NSLog(@"Error parsing data: %@", parsingError);
      failureCallback(parsingError);
      return;
    }

    // Handle the retry and bad response errors.
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if ([httpResponse statusCode] == 400) {
      if ([resultDictionary[@"error"] isEqualToString:@"authorization_pending"]) {
        // We're pending! Try again in the timeout time.
        dispatch_time_t time =
            dispatch_time(DISPATCH_TIME_NOW, code.pollingInterval * NSEC_PER_SEC);
        // TODO: Do this off the main queue :P
        __weak FIRAuthTVService *weakSelf = self;
        dispatch_after(time, dispatch_get_main_queue(), ^{
          [weakSelf pollServersWithCode:code
                        successCallback:successCallback
                        failureCallback:failureCallback];
        });
        return;
      } else {
        failureCallback([NSError errorWithDomain:@"com.firebase.auth"
                                            code:400
                                        userInfo:nil]);
      }
      return;
    }

    // Handle other errors.
    if ([httpResponse statusCode] != 200) {
      failureCallback([NSError errorWithDomain:@"com.firebase.auth"
                                          code:[httpResponse statusCode]
                                      userInfo:nil]);
      return;
    }

    // 200 Status, parse the response.
    FIRAuthTVPollResult *result = [[FIRAuthTVPollResult alloc] initWithDictionary:resultDictionary];
    successCallback(result);
  }];
  [task resume];
}

- (NSURLRequest *)postRequestWithURL:(NSURL *)url
                          parameters:(NSDictionary <NSString *, NSString *>*) parameters {
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setHTTPMethod:@"POST"];
  [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
  NSString *httpParams = [self parametersFromDictionary: parameters];
  [request setHTTPBody:[httpParams dataUsingEncoding:NSUTF8StringEncoding]];
  return request;
}

#pragma mark - Convenience Methods

- (NSString *)parametersFromDictionary:(NSDictionary<NSString *, NSString *> *)dict {
  NSMutableString *result = [[NSMutableString alloc] init];
  NSArray *allKeys = [dict allKeys];
  NSInteger keysLeft = allKeys.count;
  for (NSString *key in [dict allKeys]) {
    [result appendFormat:@"%@=%@", key, dict[key]];
    keysLeft -= 1;
    if (keysLeft > 0) {
      [result appendString:@"&"];
    }
  }

  return result;
}

- (nullable FIRAuthTVCode *)tvCodeFromData:(NSData *)data {
  NSError *parsingError = nil;
  NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:&parsingError];
  if (parsingError) {
    NSLog(@"Error parsing data: %@", parsingError);
    return nil;
  }

  FIRAuthTVCode *code = [[FIRAuthTVCode alloc] initWithDictionary:response];
  return code;
}

@end
