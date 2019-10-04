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

#import "FIRInstallationsItem.h"

#import "FIRInstallationsStoredAuthToken.h"
#import "FIRInstallationsStoredItem.h"

@implementation FIRInstallationsItem

- (instancetype)initWithAppID:(NSString *)appID firebaseAppName:(NSString *)firebaseAppName {
  self = [super init];
  if (self) {
    _appID = [appID copy];
    _firebaseAppName = [firebaseAppName copy];
  }
  return self;
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone {
  FIRInstallationsItem *clone = [[FIRInstallationsItem alloc] initWithAppID:self.appID
                                                            firebaseAppName:self.firebaseAppName];
  clone.firebaseInstallationID = [self.firebaseInstallationID copy];
  clone.refreshToken = [self.refreshToken copy];
  clone.authToken = [self.authToken copy];
  clone.registrationStatus = self.registrationStatus;

  return clone;
}

- (void)updateWithStoredItem:(FIRInstallationsStoredItem *)item {
  self.firebaseInstallationID = item.firebaseInstallationID;
  self.refreshToken = item.refreshToken;
  self.authToken = item.authToken;
  self.registrationStatus = item.registrationStatus;
}

- (FIRInstallationsStoredItem *)storedItem {
  FIRInstallationsStoredItem *storedItem = [[FIRInstallationsStoredItem alloc] init];
  storedItem.firebaseInstallationID = self.firebaseInstallationID;
  storedItem.refreshToken = self.refreshToken;
  storedItem.authToken = self.authToken;
  storedItem.registrationStatus = self.registrationStatus;
  return storedItem;
}

- (nonnull NSString *)identifier {
  return [[self class] identifierWithAppID:self.appID appName:self.firebaseAppName];
}

+ (NSString *)identifierWithAppID:(NSString *)appID appName:(NSString *)appName {
  return [appID stringByAppendingString:appName];
}

+ (NSString *)generateFID {
  NSUUID *uuid = [NSUUID UUID];
  uuid_t uuidBytes;
  [uuid getUUIDBytes:uuidBytes];

  NSData *uuidData = [NSData dataWithBytes:uuidBytes length:16];

  uint8_t prefix = 0b01110000;
  NSMutableData *fidData = [NSMutableData dataWithBytes:&prefix length:1];

  [fidData appendData:uuidData];
  NSString *fidString = [self base64URLEncodedStringWithData:fidData];

  // TODO: Consider implementation which does not modify UUID.

  // A valid FID has exactly 22 base64 characters, which is 132 bits, or 16.5 bytes.
  // Our generated ID has 16 bytes UUID + 1 byte prefix which after encoding with base64 will become
  // 23 characters plus 1 character for "=" padding.

  // Remove the 23rd character that was added because of the extra 4 bits at the
  // end of our 17 byte data. It should be pretty safe to do because UUID ends with the random part,
  // so we will not affect probability of the collisions much.
  // Also remove the '=' padding.
  return [fidString substringWithRange:NSMakeRange(0, 22)];
}

+ (NSString *)base64URLEncodedStringWithData:(NSData *)data {
  NSString *string = [data base64EncodedStringWithOptions:0];
  string = [string stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
  string = [string stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
  return string;
}

@end
