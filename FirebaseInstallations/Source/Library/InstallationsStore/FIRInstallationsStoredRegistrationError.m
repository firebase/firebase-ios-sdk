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

#import "FIRInstallationsStoredRegistrationError.h"

#import "FIRInstallationsHTTPError.h"
#import "FIRInstallationsStoredRegistrationParameters.h"

#import "FIRInstallationsLogger.h"

NSString *const kFIRInstallationsStoredRegistrationErrorRegistrationParametersKey =
    @"registrationParameters";
NSString *const kFIRInstallationsStoredRegistrationErrorAPIErrorKey = @"APIError";
NSString *const kFIRInstallationsStoredRegistrationErrorStorageVersionKey = @"storageVersion";

NSInteger const kFIRInstallationsStoredRegistrationErrorStorageVersion = 1;

@implementation FIRInstallationsStoredRegistrationError

- (instancetype)initWithRegistrationParameters:
                    (FIRInstallationsStoredRegistrationParameters *)registrationParameters
                                      APIError:(NSError *)error {
  self = [super init];
  if (self) {
    _registrationParameters = registrationParameters;
    _APIError = error;
  }
  return self;
}

- (NSInteger)storageVersion {
  return kFIRInstallationsStoredRegistrationErrorStorageVersion;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
  [coder encodeObject:self.registrationParameters
               forKey:kFIRInstallationsStoredRegistrationErrorRegistrationParametersKey];
  [coder encodeObject:self.APIError forKey:kFIRInstallationsStoredRegistrationErrorAPIErrorKey];
  [coder encodeInteger:kFIRInstallationsStoredRegistrationErrorStorageVersion
                forKey:kFIRInstallationsStoredRegistrationErrorStorageVersionKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
  NSInteger storageVersion =
      [coder decodeIntegerForKey:kFIRInstallationsStoredRegistrationErrorStorageVersionKey];
  if (storageVersion > self.storageVersion) {
    // TODO: Use a specific error code.
    FIRLogWarning(kFIRLoggerInstallations, @"I-FIS000000",
                  @"FIRInstallationsStoredRegistrationError was encoded by a newer coder version "
                  @"%ld. Current coder version is %ld. Some installation data may be lost.",
                  (long)storageVersion, (long)self.storageVersion);
  }

  FIRInstallationsStoredRegistrationParameters *registrationParameters =
      [coder decodeObjectOfClass:[FIRInstallationsStoredRegistrationParameters class]
                          forKey:kFIRInstallationsStoredRegistrationErrorRegistrationParametersKey];

  NSSet<Class> *allowedErrorClasses =
      [NSSet setWithArray:@ [[FIRInstallationsHTTPError class], [NSError class]]];
  NSError *APIError =
      [coder decodeObjectOfClasses:allowedErrorClasses
                            forKey:kFIRInstallationsStoredRegistrationErrorAPIErrorKey];

  if (registrationParameters == nil || APIError == nil) {
    // TODO: Use a specific error code.
    FIRLogWarning(kFIRLoggerInstallations, @"I-FIS000000",
                  @"Failed to decode FIRInstallationsStoredRegistrationError.");
    return nil;
  }

  return [self initWithRegistrationParameters:registrationParameters APIError:APIError];
}

@end
