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

#import "FIRInstallationsStoredIIDCheckin.h"

#import "FIRInstallationsLogger.h"

NSString *const kFIRInstallationsStoredIIDCheckinDeviceIDKey = @"deviceID";
NSString *const kFIRInstallationsStoredIIDCheckinSecretTokenKey = @"secretToken";
NSString *const kFIRInstallationsStoredIIDCheckinStorageVersionKey = @"storageVersion";

NSInteger const kFIRInstallationsStoredIIDCheckinStorageVersion = 1;

@implementation FIRInstallationsStoredIIDCheckin

- (instancetype)initWithDeviceID:(NSString *)deviceID secretToken:(NSString *)secretToken {
  self = [super init];
  if (self) {
    _deviceID = deviceID;
    _secretToken = secretToken;
  }
  return self;
}

- (NSInteger)storageVersion {
  return kFIRInstallationsStoredIIDCheckinStorageVersion;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
  [coder encodeObject:self.deviceID forKey:kFIRInstallationsStoredIIDCheckinDeviceIDKey];
  [coder encodeObject:self.secretToken forKey:kFIRInstallationsStoredIIDCheckinSecretTokenKey];
  [coder encodeInteger:self.storageVersion
                forKey:kFIRInstallationsStoredIIDCheckinStorageVersionKey];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
  NSInteger storageVersion =
      [coder decodeIntegerForKey:kFIRInstallationsStoredIIDCheckinStorageVersionKey];
  if (storageVersion > self.storageVersion) {
    FIRLogWarning(kFIRLoggerInstallations,
                  kFIRInstallationsMessageCodeIIDCheckinCoderVersionMismatch,
                  @"FIRInstallationsStoredItem was encoded by a newer coder version %ld. Current "
                  @"coder version is %ld. Some installation data may be lost.",
                  (long)storageVersion, (long)kFIRInstallationsStoredIIDCheckinStorageVersion);
  }

  NSString *deviceID = [coder decodeObjectOfClass:[NSString class]
                                           forKey:kFIRInstallationsStoredIIDCheckinDeviceIDKey];
  NSString *secretToken =
      [coder decodeObjectOfClass:[NSString class]
                          forKey:kFIRInstallationsStoredIIDCheckinSecretTokenKey];

  if (deviceID == nil || secretToken == nil) {
    FIRLogWarning(kFIRLoggerInstallations, kFIRInstallationsMessageCodeIIDCheckinFailedToDecode,
                  @"Failed to decode FIRInstallationsStoredIIDCheckin.");
    return nil;
  }

  return [self initWithDeviceID:deviceID secretToken:secretToken];
}

@end
