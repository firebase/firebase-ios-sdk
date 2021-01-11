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

#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"

#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"

/// The key used to find the APNs device token in an archive.
static NSString *const kFIRInstanceIDAPNSInfoTokenKey = @"device_token";
/// The key used to find the sandbox value in an archive.
static NSString *const kFIRInstanceIDAPNSInfoSandboxKey = @"sandbox";

@interface FIRMessagingAPNSInfo ()
/// The APNs device token, provided by the OS to the application delegate
@property(nonatomic, copy) NSData *deviceToken;
/// Represents whether or not this is deviceToken is for the sandbox
/// environment, or production.
@property(nonatomic, getter=isSandbox) BOOL sandbox;
@end

@implementation FIRMessagingAPNSInfo

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

#pragma mark - NSCopying
- (id)copyWithZone:(NSZone *)zone {
  FIRMessagingAPNSInfo *clone = [[FIRMessagingAPNSInfo alloc] init];
  clone.deviceToken = [_deviceToken copy];
  clone.sandbox = _sandbox;
  return clone;
}

#pragma mark - NSCoding

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  id deviceToken = [aDecoder decodeObjectForKey:kFIRInstanceIDAPNSInfoTokenKey];
  if (![deviceToken isKindOfClass:[NSData class]]) {
    return nil;
  }
  BOOL isSandbox = [aDecoder decodeBoolForKey:kFIRInstanceIDAPNSInfoSandboxKey];
  return [self initWithDeviceToken:(NSData *)deviceToken isSandbox:isSandbox];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:self.deviceToken forKey:kFIRInstanceIDAPNSInfoTokenKey];
  [aCoder encodeBool:self.sandbox forKey:kFIRInstanceIDAPNSInfoSandboxKey];
}

- (BOOL)isEqualToAPNSInfo:(FIRMessagingAPNSInfo *)otherInfo {
  return ([self.deviceToken isEqualToData:otherInfo.deviceToken] &&
          self.isSandbox == otherInfo.isSandbox);
}

@end
