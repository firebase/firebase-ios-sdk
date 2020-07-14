//
//  FIRFADTesterApiService.m
//  FirebaseAppDistribution
//
//  Created by Cleo Schneider on 7/14/20.
//

#import <Foundation/Foundation.h>
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"
#import "FIRFADApiService+Private.h"
#import "FIRFADLogger+Private.h"

NSString *const kFIRFADApiErrorDomain = @"com.firebase.appdistribution.api";
NSString *const kFIRFADApiErrorDetailsKey = @"details";
NSString *const kHTTPGet = @"GET";
// The App Distribution Tester API endpoint used to retrieve releases
NSString *const kReleasesEndpointURLTemplate = @"https://firebaseapptesters.googleapis.com/v1alpha/devices/"
@"-/testerApps/%@/installations/%@/releases";
NSString *const kInstallationAuthHeader = @"X-Goog-Firebase-Installations-Auth";
NSString *const kApiHeaderKey = @"X-Goog-Api-Key";
NSString *const kResponseReleasesKey = @"releases";


@implementation FIRFADApiService

+ (void)generateAuthTokenWithCompletion:(FIRFADGenerateAuthTokenCompletion)completion {
  // OR for default FIRApp:
  FIRInstallations *installations = [FIRInstallations installations];

  // Get a FIS Authentication Token.
  [installations authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable authTokenResult, NSError *_Nullable error) {

    if (error) {
      FIRFADErrorLog(@"Error getting fresh auth tokens. Error: %@",
                           [error localizedDescription]);
      [self handleError:&error
            description:@"Failed to generate Firebase Installation Auth Token."       code:FIRFADApiTokenGenerationFailure];

      completion(nil, nil, error);
      return;
    }

    [installations installationIDWithCompletion:^(NSString *__nullable identifier,
                                                  NSError *__nullable error) {

      if (error) {
        FIRFADErrorLog(@"Error getting installation id. Error: %@",
                       [error localizedDescription]);
        [self handleError:&error
              description:@"Failed to fetch Firebase Installation ID."
                     code: FIRFADApiInstallationIdentifierError];

        completion(nil, nil, error);

        return;
      }

      completion(identifier, authTokenResult, nil);
    }];
  }];
}

+ (NSMutableURLRequest *)createHTTPRequest:(NSString *)method
                                 withUrl:(NSString *)urlString withAuthToken:(FIRInstallationsAuthTokenResult *)authTokenResult {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];

     FIRFADInfoLog(@"Requesting releases for app id - %@", [[FIRApp defaultApp] options].googleAppID);
    [request setURL:[NSURL URLWithString:urlString]];
    [request setHTTPMethod:method];
    [request setValue:authTokenResult.authToken forHTTPHeaderField:kInstallationAuthHeader];
    [request setValue:[[FIRApp defaultApp] options].APIKey forHTTPHeaderField:kApiHeaderKey];
    return request;
}

+ (NSArray *) handleReleaseResponse:(NSData *)data response:(NSURLResponse *)response error:(NSError ** _Nullable)error {
  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  FIRFADInfoLog(@"HTTPResonse status code %ld response %@", (long)httpResponse.statusCode,
        httpResponse);

  if (error || !httpResponse) {
    [self handleError:error
          description:@"Unknown http error occurred"
                 code:FIRApiErrorUnknownFailure];

    FIRFADErrorLog(@"App Tester API service error - %@", [*error localizedDescription]);
    return nil;

  }

  if(httpResponse.statusCode != 200) {
    [self handleErrorWithStatusCode:httpResponse.statusCode error:error];
    return nil;
  }

  return [self parseApiResponseWithData:data error:error];
}

+ (void)fetchReleasesWithCompletion:(FIRFADFetchReleasesCompletion)completion {

  void (^executeFetch)(NSString * _Nullable, FIRInstallationsAuthTokenResult *, NSError * _Nullable) = ^(NSString * _Nullable identifier, FIRInstallationsAuthTokenResult *authTokenResult, NSError * _Nullable error) {
    NSString *urlString =
    [NSString stringWithFormat:kReleasesEndpointURLTemplate, [[FIRApp defaultApp] options].googleAppID, identifier];
    NSMutableURLRequest *request = [self createHTTPRequest:@"GET" withUrl:urlString withAuthToken:authTokenResult];

    FIRFADInfoLog(@"Url : %@, Auth token: %@ API KEY: %@", urlString, authTokenResult.authToken,
          [[FIRApp defaultApp] options].APIKey);

    NSURLSessionDataTask *listReleasesDataTask = [[NSURLSession sharedSession]
                                                  dataTaskWithRequest:request
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      NSArray *releases =[self handleReleaseResponse:data response:response error:&error];
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(releases, error);
      });
    }];

    [listReleasesDataTask resume];
  };

  [self generateAuthTokenWithCompletion:executeFetch];
}

+ (void)handleErrorWithStatusCode:(NSInteger)statusCode
                            error:(NSError **_Nullable)error {
  if(statusCode == 401) {
    [self handleError:error
          description:@"Tester not authenticated."
                 code:FIRFADApiErrorUnauthenticated];
    return;
  }

  if(statusCode == 403 || statusCode == 400) {
    [self handleError:error
          description:@"Tester not authorized."
                 code:FIRFADApiErrorUnauthorized];
    return;
  }

  if(statusCode == 404) {
    [self handleError:error
          description:@"Tester or releases not found"
                 code:FIRFADApiErrorUnauthorized];
    return;
  }

  if(statusCode == 408 || statusCode == 504){
    [self handleError:error
          description:@"Request timeout."
                 code:FIRFADApiErrorTimeout];
    return;
  }

  FIRFADErrorLog(@"Encountered unmapped status code: %@", statusCode);
  NSString *description = (*error).userInfo[NSLocalizedDescriptionKey] ? (*error).userInfo[NSLocalizedDescriptionKey] : [NSString stringWithFormat:@"Unknown status code: %@", statusCode];
  [self handleError:error description:description code:FIRApiErrorUnknownFailure];
}


+ (void)handleError:(NSError **_Nullable)error
                              description:(NSString *)description
                                     code:(FIRFADApiError)code {
  if (error) {
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey : description};
    *error = [NSError errorWithDomain:kFIRFADApiErrorDomain
                                 code:code
                             userInfo:userInfo];
  }
}

+ (NSArray *_Nullable)parseApiResponseWithData:(NSData *)data error:(NSError **_Nullable)error {

  NSDictionary *serializedResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:0
                                                                       error:error];
  if (error) {
    FIRFADErrorLog(@"Tester API - Error deserializing json response");
    NSString *description =
    (*error).userInfo[NSLocalizedDescriptionKey] ? (*error).userInfo[NSLocalizedDescriptionKey] : @"Failed to parse response";
    [self handleError:error description:description code:FIRApiErrorParseFailure];

    return nil;
  }

  NSArray* releases = [serializedResponse objectForKey:kResponseReleasesKey];
  if(releases.count == 0){
    [self handleError:error
          description:@"No releases found for tester."
                 code:FIRFADApiErrorNotFound];
    return nil;
  }

  return releases;
}

@end
