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

#import <leveldb/slice.h>
#import "Firestore/Source/Local/StringView.h"

#import <XCTest/XCTest.h>

using Firestore::StringView;

@interface StringViewTests : XCTestCase
@end

@implementation StringViewTests

- (void)testStringViewNSStringToSliceWithUSAscii {
  NSString *usAsciiChars = @"abcdefg ABCDEFG 12345 !@#$%";
  [self convertNSStringToStringViewAndBackAndEnsureEqual:usAsciiChars];
}

- (void)testStringViewNSStringToSliceWithNonUSAscii {
  NSString *nonUsAsciiChars = @"ó¹";
  [self convertNSStringToStringViewAndBackAndEnsureEqual:nonUsAsciiChars];
}

- (void)convertNSStringToStringViewAndBackAndEnsureEqual:(NSString *)str {
  StringView sv(str);
  leveldb::Slice slice = sv;
  NSString *afterConversion = [[NSString alloc] initWithBytes:slice.data()
                                                       length:slice.size()
                                                     encoding:NSUTF8StringEncoding];
  XCTAssertTrue([str isEqualToString:afterConversion]);
}

@end
