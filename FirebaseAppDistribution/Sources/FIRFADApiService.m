// Copyright 2020 Google LLC
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
#import "FirebaseAppDistribution/Sources/FIRFADApiService.h"
#import <Foundation/Foundation.h>
#import "FirebaseAppDistribution/Sources/FIRFADLogger.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

NSString *const kFIRFADApiErrorDomain = @"com.firebase.appdistribution.api";
NSString *const kFIRFADApiErrorDetailsKey = @"details";
NSString *const kHTTPGet = @"GET";
// The App Distribution Tester API endpoint used to retrieve releases
NSString *const kReleasesEndpointURLTemplate =
    @"https://firebaseapptesters.googleapis.com/v1alpha/devices/"
    @"-/testerApps/%@/installations/%@/releases";
NSString *const kInstallationAuthHeader = @"X-Goog-Firebase-Installations-Auth";
NSString *const kApiHeaderKey = @"X-Goog-Api-Key";
NSString *const kApiBundleKey = @"X-Ios-Bundle-Identifier";
NSString *const kResponseReleasesKey = @"releases";

@implementation FIRFADApiService

+ (void)generateAuthTokenWithCompletion:(FIRFADGenerateAuthTokenCompletion)completion {
  FIRInstallations *installations = [FIRInstallations installations];

  // Get a FIS Authentication Token.
  [installations authTokenWithCompletion:^(
                     FIRInstallationsAuthTokenResult *_Nullable authTokenResult,
                     NSError *_Nullable error) {
    if ([self handleError:&error
              description:@"Failed to generate Firebase installation auth token."
                     code:FIRFADApiTokenGenerationFailure]) {
      FIRFADErrorLog(@"Error getting fresh auth tokens. Error: %@", [error localizedDescription]);

      completion(nil, nil, error);
      return;
    }

    [installations installationIDWithCompletion:^(NSString *__nullable identifier,
                                                  NSError *__nullable error) {
      if ([self handleError:&error
                description:@"Failed to fetch Firebase Installation ID."
                       code:FIRFADApiInstallationIdentifierError]) {
        FIRFADErrorLog(@"Error getting installation id. Error: %@", [error localizedDescription]);

        completion(nil, nil, error);

        return;
      }

      completion(identifier, authTokenResult, nil);
    }];
  }];
}

+ (NSMutableURLRequest *)createHTTPRequest:(NSString *)method
                                   withUrl:(NSString *)urlString
                             withAuthToken:(FIRInstallationsAuthTokenResult *)authTokenResult {
  NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

  FIRFADInfoLog(@"Requesting releases for app id - %@", [[FIRApp defaultApp] options].googleAppID);
  [request setURL:[NSURL URLWithString:urlString]];
  [request setHTTPMethod:method];
  [request setValue:authTokenResult.authToken forHTTPHeaderField:kInstallationAuthHeader];
  [request setValue:[[FIRApp defaultApp] options].APIKey forHTTPHeaderField:kApiHeaderKey];
  [request setValue:[NSBundle mainBundle].bundleIdentifier forHTTPHeaderField:kApiBundleKey];
  return request;
}

+ (NSString *)tryParseGoogleAPIErrorFromResponse:(NSData *)data {
  if (!data) {
    return @"No data in response.";
  }

  NSError *parseError;
  NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:0
                                                                 error:&parseError];
  if (parseError) {
    return @"Could not parse additional details about this API error.";
  } else {
    NSDictionary *errorDict = [responseDict objectForKey:@"error"];
    if (!errorDict) {
      return @"Could not parse additional details about this API error.";
    }

    NSString *message = [errorDict objectForKey:@"message"];
    if (!message) {
      return @"Could not parse additional details about this API error.";
    }
    return message;
  }
}

+ (NSArray *)handleReleaseResponse:(NSData *)data
                          response:(NSURLResponse *)response
                             error:(NSError **_Nullable)error {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  FIRFADInfoLog(@"HTTPResonse status code %ld response %@", (long)[httpResponse statusCode],
                httpResponse);

  if ([self handleHttpResponseError:httpResponse error:error]) {
    FIRFADErrorLog(@"App Tester API service error: %@. %@", [*error localizedDescription],
                   [self tryParseGoogleAPIErrorFromResponse:data]);
    return nil;
  }

  return [self parseApiResponseWithData:data error:error];
}

+ (void)fetchReleasesWithCompletion:(FIRFADFetchReleasesCompletion)completion {
  void (^executeFetch)(NSString *_Nullable, FIRInstallationsAuthTokenResult *, NSError *_Nullable) =
      ^(NSString *_Nullable identifier, FIRInstallationsAuthTokenResult *authTokenResult,
        NSError *_Nullable error) {
        NSString *urlString =
            [NSString stringWithFormat:kReleasesEndpointURLTemplate,
                                       [[FIRApp defaultApp] options].googleAppID, identifier];
        NSMutableURLRequest *request = [self createHTTPRequest:@"GET"
                                                       withUrl:urlString
                                                 withAuthToken:authTokenResult];

        FIRFADInfoLog(@"Url : %@, Auth token: %@ API KEY: %@", urlString, authTokenResult.authToken,
                      [[FIRApp defaultApp] options].APIKey);

        NSURLSessionDataTask *listReleasesDataTask = [[NSURLSession sharedSession]
            dataTaskWithRequest:request
              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSArray *releases = [self handleReleaseResponse:data
                                                       response:response
                                                          error:&error];
                dispatch_async(dispatch_get_main_queue(), ^{
                  completion(releases, error);
                });
              }];

        [listReleasesDataTask resume];
      };

  [self generateAuthTokenWithCompletion:executeFetch];
}

+ (BOOL)handleHttpResponseError:(NSHTTPURLResponse *)httpResponse error:(NSError **_Nullable)error {
  if (*error || !httpResponse) {
    return [self handleError:error
                 description:@"Unknown http error occurred"
                        code:FIRApiErrorUnknownFailure];
  }

  if ([httpResponse statusCode] != 200) {
    *error = [self createErrorFromStatusCode:[httpResponse statusCode]];
    return YES;
  }

  return NO;
}

+ (NSError *)createErrorFromStatusCode:(NSInteger)statusCode {
  if (statusCode == 401) {
    return [self createErrorWithDescription:@"Tester not authenticated"
                                       code:FIRFADApiErrorUnauthenticated];
  }

  if (statusCode == 403 || statusCode == 400) {
    return [self createErrorWithDescription:@"Tester not authorized"
                                       code:FIRFADApiErrorUnauthorized];
  }

  if (statusCode == 404) {
    return [self createErrorWithDescription:@"Tester or releases not found"
                                       code:FIRFADApiErrorUnauthorized];
  }

  if (statusCode == 408 || statusCode == 504) {
    return [self createErrorWithDescription:@"Request timeout" code:FIRFADApiErrorTimeout];
  }

  FIRFADErrorLog(@"Encountered unmapped status code: %ld", (long)statusCode);
  NSString *description = [NSString stringWithFormat:@"Unknown status code: %ld", (long)statusCode];
  return [self createErrorWithDescription:description code:FIRApiErrorUnknownFailure];
}

+ (BOOL)handleError:(NSError **_Nullable)error
        description:(NSString *)description
               code:(FIRFADApiError)code {
  if (*error) {
    *error = [self createErrorWithDescription:description code:code];
    return YES;
  }

  return NO;
}

+ (NSError *)createErrorWithDescription:description code:(FIRFADApiError)code {
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};
  return [NSError errorWithDomain:kFIRFADApiErrorDomain code:code userInfo:userInfo];
}

+ (NSArray *_Nullable)parseApiResponseWithData:(NSData *)data error:(NSError **_Nullable)error {
  NSDictionary *serializedResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:error];
  if (*error) {
    FIRFADErrorLog(@"Tester API - Error deserializing json response");
    NSString *description = (*error).userInfo[NSLocalizedDescriptionKey]
                                ? (*error).userInfo[NSLocalizedDescriptionKey]
                                : @"Failed to parse response";
    [self handleError:error description:description code:FIRApiErrorParseFailure];

    return nil;
  }

  NSArray *releases = [serializedResponse objectForKey:kResponseReleasesKey];

  return releases;
}

@end
