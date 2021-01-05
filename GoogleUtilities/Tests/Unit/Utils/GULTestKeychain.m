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

#import <TargetConditionals.h>
#if TARGET_OS_OSX

#import "GoogleUtilities/Tests/Unit/Utils/GULTestKeychain.h"

#import <XCTest/XCTest.h>

@implementation GULTestKeychain

- (nullable instancetype)init {
  self = [super init];
  if (self) {
    SecKeychainRef privateKeychain;
    NSString *keychainPath =
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"GULTestKeychain"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:keychainPath]) {
      NSError *error;
      if (![[NSFileManager defaultManager] removeItemAtPath:keychainPath error:&error]) {
        NSLog(@"Failed to delete existing test keychain: %@", error);
        return nil;
      }
    }
    OSStatus result = SecKeychainCreate([keychainPath cStringUsingEncoding:NSUTF8StringEncoding], 0,
                                        "1", false, nil, &privateKeychain);
    if (result != errSecSuccess) {
      NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:nil];
      NSLog(@"SecKeychainCreate error: %@", error);
      return nil;
    }
    _testKeychainRef = privateKeychain;
  }
  return self;
}

- (void)dealloc {
  if (self.testKeychainRef) {
    OSStatus result = SecKeychainDelete(self.testKeychainRef);
    if (result != errSecSuccess) {
      NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:result userInfo:nil];
      NSLog(@"SecKeychainCreate error: %@", error);
    }

    CFRelease(self.testKeychainRef);
  }
}

@end

#endif  // TARGET_OSX
