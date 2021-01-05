/*
 * Copyright 2017 Google
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

#import "FirebaseDatabase/Tests/Helpers/FTestContants.h"
#import "FirebaseDatabase/Tests/Helpers/SenTest+FWaiter.h"

@implementation XCTestCase (FWaiter)

- (NSTimeInterval)waitUntil:(BOOL (^)(void))predicate {
  return [self waitUntil:predicate timeout:kFirebaseTestWaitUntilTimeout description:nil];
}

- (NSTimeInterval)waitUntil:(BOOL (^)(void))predicate description:(NSString *)desc {
  return [self waitUntil:predicate timeout:kFirebaseTestWaitUntilTimeout description:desc];
}

- (NSTimeInterval)waitUntil:(BOOL (^)(void))predicate timeout:(NSTimeInterval)seconds {
  return [self waitUntil:predicate timeout:seconds description:nil];
}

- (NSTimeInterval)waitUntil:(BOOL (^)(void))predicate
                    timeout:(NSTimeInterval)seconds
                description:(NSString *)desc {
  NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
  NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:seconds];
  NSTimeInterval timeoutTime = [timeoutDate timeIntervalSinceReferenceDate];
  NSTimeInterval currentTime;

  for (currentTime = [NSDate timeIntervalSinceReferenceDate];
       !predicate() && currentTime < timeoutTime;
       currentTime = [NSDate timeIntervalSinceReferenceDate]) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
  }

  NSTimeInterval finish = [NSDate timeIntervalSinceReferenceDate];
  if (currentTime > timeoutTime) {
    if (desc != nil) {
      XCTFail("Timed out on: %@", desc);
    } else {
      XCTFail("Timed out");
    }
  }
  return (finish - start);
}

@end
