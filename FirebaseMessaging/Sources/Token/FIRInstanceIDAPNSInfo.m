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

#import "FIRInstanceIDAPNSInfo.h"

#import "FIRMessagingConstants.h"

/// The key used to find the APNs device token in an archive.
NSString *const kFIRMessagingAPNSInfoTokenKey = @"device_token";
/// The key used to find the sandbox value in an archive.
NSString *const kFIRMessagingAPNSInfoSandboxKey = @"sandbox";

@implementation FIRInstanceIDAPNSInfo

- (instancetype)initWithDeviceToken:(NSData *)deviceToken isSandbox:(BOOL)isSandbox {
  self = [super init];
  if (self) {
    _deviceToken = [deviceToken copy];
    _sandbox = isSandbox;
  }
  return self;
}

- (instancetype)initWithTokenOptionsDictionary:(NSDictionary *)dictionary {
  id deviceToken = dictionary[kFIRMessagingTokenOptionsAPNSKey];
  if (![deviceToken isKindOfClass:[NSData class]]) {
    return nil;
  }

  id isSandbox = dictionary[kFIRMessagingTokenOptionsAPNSIsSandboxKey];
  if (![isSandbox isKindOfClass:[NSNumber class]]) {
    return nil;
  }
  self = [super init];
  if (self) {
    _deviceToken = (NSData *)deviceToken;
    _sandbox = ((NSNumber *)isSandbox).boolValue;
  }
  return self;
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  id deviceToken = [aDecoder decodeObjectForKey:kFIRMessagingAPNSInfoTokenKey];
  if (![deviceToken isKindOfClass:[NSData class]]) {
    return nil;
  }
  BOOL isSandbox = [aDecoder decodeBoolForKey:kFIRMessagingAPNSInfoSandboxKey];
  return [self initWithDeviceToken:(NSData *)deviceToken isSandbox:isSandbox];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.deviceToken forKey:kFIRMessagingAPNSInfoTokenKey];
  [aCoder encodeBool:self.sandbox forKey:kFIRMessagingAPNSInfoSandboxKey];
}

- (BOOL)isEqualToAPNSInfo:(FIRInstanceIDAPNSInfo *)otherInfo {
  if ([super isEqual:otherInfo]) {
    return YES;
  }
  return ([self.deviceToken isEqualToData:otherInfo.deviceToken] &&
          self.isSandbox == otherInfo.isSandbox);
}

@end
