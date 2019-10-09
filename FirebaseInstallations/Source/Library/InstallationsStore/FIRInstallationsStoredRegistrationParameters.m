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

#import "FIRInstallationsStoredRegistrationParameters.h"

#import "FIRInstallationsLogger.h"

NSString *const kFIRInstallationsStoredRegistrationParametersAPIKeyKey = @"APIKey";
NSString *const kFIRInstallationsStoredRegistrationParametersProjectID = @"projectID";
NSString *const FIRInstallationsStoredRegistrationParametersStorageVersionKey = @"storageVersion";

NSInteger const FIRInstallationsStoredRegistrationParametersStorageVersion = 1;

@implementation FIRInstallationsStoredRegistrationParameters

- (instancetype)initWithAPIKey:(NSString *)APIKey projectID:(NSString *)projectID {
  self = [super init];
  if (self) {
    _APIKey = APIKey;
    _projectID = projectID;
  }
  return self;
}

- (NSInteger)storageVersion {
  return FIRInstallationsStoredRegistrationParametersStorageVersion;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
  [coder encodeObject:self.APIKey forKey:kFIRInstallationsStoredRegistrationParametersAPIKeyKey];
  [coder encodeObject:self.projectID forKey:kFIRInstallationsStoredRegistrationParametersProjectID];
  [coder encodeInteger:self.storageVersion
                forKey:FIRInstallationsStoredRegistrationParametersStorageVersionKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
  NSInteger storageVersion =
      [coder decodeIntegerForKey:FIRInstallationsStoredRegistrationParametersStorageVersionKey];
  if (storageVersion > self.storageVersion) {
    FIRLogWarning(kFIRLoggerInstallations,
                  kFIRInstallationsMessageCodeRegistrationParametersCoderVersionMismatch,
                  @"FIRInstallationsStoredRegistrationParameters was encoded by a newer coder "
                  @"version %ld. Current coder version is %ld. Some installation data may be lost.",
                  (long)storageVersion, (long)self.storageVersion);
  }

  NSString *APIKey =
      [coder decodeObjectForKey:kFIRInstallationsStoredRegistrationParametersAPIKeyKey];
  NSString *projectID =
      [coder decodeObjectForKey:kFIRInstallationsStoredRegistrationParametersProjectID];

  return [self initWithAPIKey:APIKey projectID:projectID];
}

@end
