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

#import "FIRInstallationsItem+RegisterInstallationAPI.h"

#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsStoredAuthToken.h"

void FIRSetErrorToPointer(NSError *error, NSError **pointer) {
  if (pointer != NULL) {
    *pointer = error;
  }
}

@implementation FIRInstallationsItem (RegisterInstallationAPI)

- (nullable FIRInstallationsItem *)registeredInstallationWithJSONData:(NSData *)data
                                                                 date:(NSDate *)date
                                                                error:(NSError **)outError {
  // Let's require `outError` other
  if (outError == NULL) {
    return nil;
  }

  NSError *error;
  NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];

  if (responseJSON == nil) {
    FIRSetErrorToPointer([FIRInstallationsErrorUtil JSONSerializationError:error], outError);
    return nil;
  }

  NSString *refreshToken = [self validStringOrNilForKey:@"refreshToken" fromDict:responseJSON];
  if (refreshToken == nil) {
    FIRSetErrorToPointer(
        [FIRInstallationsErrorUtil FIDRegestrationErrorWithResponseMissingField:@"refreshToken"],
        outError);
    return nil;
  }

  NSDictionary *authTokenDict = responseJSON[@"authToken"];
  if (![authTokenDict isKindOfClass:[NSDictionary class]]) {
    FIRSetErrorToPointer(
        [FIRInstallationsErrorUtil FIDRegestrationErrorWithResponseMissingField:@"authToken"],
        outError);
    return nil;
  }

  FIRInstallationsStoredAuthToken *authToken = [self authTokenWithJSONDict:authTokenDict
                                                                      date:date
                                                                     error:outError];
  if (authToken == nil) {
    return nil;
  }

  FIRInstallationsItem *installation =
      [[FIRInstallationsItem alloc] initWithAppID:self.appID firebaseAppName:self.firebaseAppName];
  installation.firebaseInstallationID = self.firebaseInstallationID;
  installation.refreshToken = refreshToken;
  installation.authToken = authToken;
  installation.registrationStatus = FIRInstallationStatusRegistered;

  return installation;
}

- (NSString *)validStringOrNilForKey:(NSString *)key fromDict:(NSDictionary *)dict {
  NSString *string = dict[key];
  if ([string isKindOfClass:[NSString class]] && string.length > 0) {
    return string;
  }
  return nil;
}

- (nullable FIRInstallationsStoredAuthToken *)authTokenWithJSONDict:(NSDictionary *)dict
                                                               date:(NSDate *)date
                                                              error:(NSError **)outError {
  NSString *token = [self validStringOrNilForKey:@"token" fromDict:dict];
  if (token == nil) {
    FIRSetErrorToPointer(
        [FIRInstallationsErrorUtil FIDRegestrationErrorWithResponseMissingField:@"authToken.token"],
        outError);
    return nil;
  }

  NSString *expiresInString = [self validStringOrNilForKey:@"expiresIn" fromDict:dict];
  if (expiresInString == nil) {
    FIRSetErrorToPointer([FIRInstallationsErrorUtil
                             FIDRegestrationErrorWithResponseMissingField:@"authToken.expiresIn"],
                         outError);
    return nil;
  }

  // The response should contain the string in format like "604800s".
  // The server should never response with anything else except seconds.
  // Just drop the last character and parse a number from string.
  NSString *expiresInSeconds = [expiresInString substringToIndex:expiresInString.length - 1];
  NSTimeInterval expiresIn = [expiresInSeconds doubleValue];
  NSDate *experationDate = [date dateByAddingTimeInterval:expiresIn];

  FIRInstallationsStoredAuthToken *authToken = [[FIRInstallationsStoredAuthToken alloc] init];
  authToken.status = FIRInstallationsAuthTokenStatusTokenReceived;
  authToken.token = token;
  authToken.expirationDate = experationDate;

  return authToken;
}

@end
