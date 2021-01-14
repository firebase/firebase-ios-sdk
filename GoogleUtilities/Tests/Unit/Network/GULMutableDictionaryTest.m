// Copyright 2018 Google
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

#import <XCTest/XCTest.h>

#import "GoogleUtilities/Network/Public/GoogleUtilities/GULMutableDictionary.h"

const static NSString *const kKey = @"testKey1";
const static NSString *const kValue = @"testValue1";
const static NSString *const kKey2 = @"testKey2";
const static NSString *const kValue2 = @"testValue2";

@interface GULMutableDictionaryTest : XCTestCase
@property(nonatomic) GULMutableDictionary *dictionary;
@end

@implementation GULMutableDictionaryTest

- (void)setUp {
  [super setUp];
  self.dictionary = [[GULMutableDictionary alloc] init];
}

- (void)tearDown {
  self.dictionary = nil;
  [super tearDown];
}

- (void)testSetGetAndRemove {
  XCTAssertNil([self.dictionary objectForKey:kKey]);
  [self.dictionary setObject:kValue forKey:kKey];
  XCTAssertEqual(kValue, [self.dictionary objectForKey:kKey]);
  [self.dictionary removeObjectForKey:kKey];
  XCTAssertNil([self.dictionary objectForKey:kKey]);
}

- (void)testSetGetAndRemoveKeyed {
  XCTAssertNil(self.dictionary[kKey]);
  self.dictionary[kKey] = kValue;
  XCTAssertEqual(kValue, self.dictionary[kKey]);
  [self.dictionary removeObjectForKey:kKey];
  XCTAssertNil(self.dictionary[kKey]);
}

- (void)testRemoveAll {
  XCTAssertNil(self.dictionary[kKey]);
  XCTAssertNil(self.dictionary[kKey2]);
  self.dictionary[kKey] = kValue;
  self.dictionary[kKey2] = kValue2;
  [self.dictionary removeAllObjects];
  XCTAssertNil(self.dictionary[kKey]);
  XCTAssertNil(self.dictionary[kKey2]);
}

- (void)testCount {
  XCTAssertEqual([self.dictionary count], 0);
  self.dictionary[kKey] = kValue;
  XCTAssertEqual([self.dictionary count], 1);
  self.dictionary[kKey2] = kValue2;
  XCTAssertEqual([self.dictionary count], 2);
  [self.dictionary removeAllObjects];
  XCTAssertEqual([self.dictionary count], 0);
}

- (void)testUnderlyingDictionary {
  XCTAssertEqual([self.dictionary count], 0);
  self.dictionary[kKey] = kValue;
  self.dictionary[kKey2] = kValue2;

  NSDictionary *dict = self.dictionary.dictionary;
  XCTAssertEqual([dict count], 2);
  XCTAssertEqual(dict[kKey], kValue);
  XCTAssertEqual(dict[kKey2], kValue2);
}

@end
