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

#import <XCTest/XCTest.h>

#import "FirebaseRemoteConfig/Sources/RCNConfigValue_Internal.h"

@interface FIRRemoteConfigValueTest : XCTestCase
@end

@implementation FIRRemoteConfigValueTest
- (void)testConfigValueWithDifferentValueTypes {
  NSString *valueA = @"0.33333";
  NSData *dataA = [valueA dataUsingEncoding:NSUTF8StringEncoding];

  FIRRemoteConfigValue *configValueA =
      [[FIRRemoteConfigValue alloc] initWithData:dataA source:FIRRemoteConfigSourceRemote];
  XCTAssertEqualObjects(configValueA.stringValue, valueA);
  XCTAssertEqualObjects(configValueA.dataValue, dataA);
  XCTAssertEqualObjects(configValueA.numberValue, configValueA.numberValue);
  XCTAssertEqual(configValueA.boolValue, valueA.boolValue);

  NSString *valueB = @"NO";
  FIRRemoteConfigValue *configValueB =
      [[FIRRemoteConfigValue alloc] initWithData:[valueB dataUsingEncoding:NSUTF8StringEncoding]
                                          source:FIRRemoteConfigSourceRemote];
  XCTAssertEqual(configValueB.boolValue, valueB.boolValue);

  // Test JSON value.
  NSDictionary<NSString *, NSString *> *JSONDictionary = @{@"key1" : @"value1"};
  NSArray<NSDictionary<NSString *, NSString *> *> *JSONArray =
      @[ @{@"key1" : @"value1"}, @{@"key2" : @"value2"} ];
  NSError *error;
  NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSONDictionary options:0 error:&error];
  FIRRemoteConfigValue *configValueC =
      [[FIRRemoteConfigValue alloc] initWithData:JSONData source:FIRRemoteConfigSourceRemote];
  XCTAssertEqualObjects(configValueC.JSONValue, JSONDictionary);

  NSData *JSONArrayData = [NSJSONSerialization dataWithJSONObject:JSONArray options:0 error:&error];
  FIRRemoteConfigValue *configValueD =
      [[FIRRemoteConfigValue alloc] initWithData:JSONArrayData source:FIRRemoteConfigSourceRemote];
  XCTAssertEqualObjects(configValueD.JSONValue, JSONArray);
}

- (void)testFIRRemoteConfigValueToNumber {
  FIRRemoteConfigValue *value;

  NSString *strValue = @"0.33";
  NSData *data = [strValue dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:data source:FIRRemoteConfigSourceRemote];
  XCTAssertEqual(value.numberValue.floatValue, strValue.floatValue);

  strValue = @"3.14159265358979";
  data = [strValue dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:data source:FIRRemoteConfigSourceRemote];
  XCTAssertEqual(value.numberValue.doubleValue, strValue.doubleValue);

  strValue = @"1000000000";
  data = [strValue dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:data source:FIRRemoteConfigSourceRemote];
  XCTAssertEqual(value.numberValue.intValue, strValue.intValue);

  strValue = @"1000000000123";
  data = [strValue dataUsingEncoding:NSUTF8StringEncoding];
  value = [[FIRRemoteConfigValue alloc] initWithData:data source:FIRRemoteConfigSourceRemote];
  XCTAssertEqual(value.numberValue.longLongValue, strValue.longLongValue);
}

@end
