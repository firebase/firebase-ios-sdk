// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseCore/Tests/SwiftUnit/SwiftTestingUtilities/ExceptionCatcher.h"

@implementation ExceptionCatcher

+ (BOOL)catchException:(ThrowingBlock)block error:(__autoreleasing NSError **)error {
  @try {
    block();
    return YES;
  } @catch (NSException *exception) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setValue:exception.name forKey:@"ExceptionName"];
    [info setValue:exception.reason forKey:@"ExceptionReason"];
    [info setValue:exception.callStackReturnAddresses forKey:@"ExceptionCallStackReturnAddresses"];
    [info setValue:exception.callStackSymbols forKey:@"ExceptionCallStackSymbols"];
    [info setValue:exception.userInfo forKey:@"ExceptionUserInfo"];

    // Just using error code `FIRErrorCodeConfigFailed` for now
    NSInteger FIRErrorCodeConfigFailed = -114;
    *error = [[NSError alloc] initWithDomain:exception.name
                                        code:FIRErrorCodeConfigFailed
                                    userInfo:info];
    return NO;
  }
}

@end
