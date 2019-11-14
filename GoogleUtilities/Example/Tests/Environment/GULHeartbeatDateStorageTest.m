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

#import <GoogleUtilities/GULHeartbeatDateStorage.h>
#import <XCTest/XCTest.h>

@interface GULHeartbeatDateStorageTest : XCTestCase
@property(nonatomic) NSURL *fileURL;
@property(nonatomic) GULHeartbeatDateStorage *storage;
@end

@implementation GULHeartbeatDateStorageTest

- (void)setUp {
  NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  XCTAssertNotNil(documentsPath);
  NSURL *documentsURL = [NSURL fileURLWithPath:documentsPath];

  NSError *error;
  if (![documentsURL checkResourceIsReachableAndReturnError:&error]) {
    XCTAssert([[NSFileManager defaultManager] createDirectoryAtURL:documentsURL
                                       withIntermediateDirectories:YES
                                                        attributes:nil
                                                             error:&error],
              @"Error: %@", error);
  }
  self.storage = [[GULHeartbeatDateStorage alloc] initWithFileName:@"GULStorageHeartbeatTest"];
}

- (void)tearDown {
  [[NSFileManager defaultManager] removeItemAtURL:[self.storage fileURL] error:nil];
  self.storage = nil;
}

- (void)testHeartbeatDateForTag {
  NSDate *now = [NSDate date];
  [self.storage setHearbeatDate:now forTag:@"fire-iid"];
  XCTAssertEqual([now timeIntervalSinceReferenceDate],
                 [[self.storage heartbeatDateForTag:@"fire-iid"] timeIntervalSinceReferenceDate]);
}

@end
