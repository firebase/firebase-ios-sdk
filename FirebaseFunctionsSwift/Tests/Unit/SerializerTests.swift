// Copyright 2022 Google LLC
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

import Foundation

import FirebaseCore
@testable import FirebaseFunctionsSwift
#if COCOAPODS
  import GTMSessionFetcher
#else
  import GTMSessionFetcherCore
#endif

import XCTest

class SerializerTests: XCTestCase {
  func testEncodeNull() throws {
    let serializer = FUNSerializer()
    let null = NSNull()
    XCTAssertEqual(try serializer.encode(null) as? NSNull, null)
  }

  func testDecodeNull() throws {
    let serializer = FUNSerializer()
    let null = NSNull()
    XCTAssertEqual(try serializer.decode(null) as? NSNull, null)
  }

  func testEncodeInt32() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(value: 1 as Int32)
    XCTAssertEqual(one, try serializer.encode(one) as? NSNumber)
  }

  func testEncodeInt() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(1)
    let dict = try XCTUnwrap(try serializer.encode(one) as? NSDictionary)
    XCTAssertEqual("type.googleapis.com/google.protobuf.Int64Value", dict["@type"] as? String)
    XCTAssertEqual("1", dict["value"] as? String)
  }

  func testDecodeInt32() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(value: 1 as Int32)
    XCTAssertEqual(one, try serializer.decode(one) as? NSNumber)
  }

  func testDecodeInt() throws {
    let serializer = FUNSerializer()
    let one = NSNumber(1)
    XCTAssertEqual(one, try serializer.decode(one) as? NSNumber)
  }

  // - (void)testDecodeInt {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(@1, [serializer decode:@1 error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testEncodeLong {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSDictionary *expected = @{
//    @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//    @"value" : @"-9223372036854775800",
//  };
//  XCTAssertEqualObjects(expected, [serializer encode:@-9223372036854775800L]);
  // }
//
  // - (void)testDecodeLong {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSDictionary *input = @{
//    @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//    @"value" : @"-9223372036854775800",
//  };
//  NSError *error = nil;
//  NSNumber *actual = [serializer decode:input error:&error];
//  XCTAssertEqualObjects(@-9223372036854775800L, actual);
//  // A naive implementation might convert a number to a double and think that's close enough.
//  // We need to make sure it's a long long for accuracy.
//  XCTAssertEqual('q', actual.objCType[0]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testDecodeInvalidLong {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSDictionary *input = @{
//    @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//    @"value" : @"-9223372036854775800 and some other junk",
//  };
//  NSError *error = nil;
//  NSNumber *actual = [serializer decode:input error:&error];
//  XCTAssertNil(actual);
//  XCTAssertNotNil(error);
//  XCTAssertEqualObjects(FIRFunctionsErrorDomain, error.domain);
//  XCTAssertEqual(FIRFunctionsErrorCodeInternal, error.code);
  // }
//
  // - (void)testEncodeUnsignedLong {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSDictionary *expected = @{
//    @"@type" : @"type.googleapis.com/google.protobuf.UInt64Value",
//    @"value" : @"18446744073709551600",
//  };
//  XCTAssertEqualObjects(expected, [serializer encode:@18446744073709551600UL]);
  // }
//
  // - (void)testDecodeUnsignedLong {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSDictionary *input = @{
//    @"@type" : @"type.googleapis.com/google.protobuf.UInt64Value",
//    @"value" : @"17446744073709551688",
//  };
//  NSError *error = nil;
//  NSNumber *actual = [serializer decode:input error:&error];
//  XCTAssertEqualObjects(@17446744073709551688UL, actual);
//  // A naive NSNumberFormatter implementation will convert the number to a double and think
//  // that's close enough. We need to make sure it's an unsigned long long for accuracy.
//  XCTAssertEqual('Q', actual.objCType[0]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testEncodeDouble {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  XCTAssertEqualObjects(@1.2, [serializer encode:@1.2]);
  // }
//
  // - (void)testDecodeDouble {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(@1.2, [serializer decode:@1.2 error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testEncodeBool {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  XCTAssertEqualObjects(@YES, [serializer encode:@YES]);
  // }
//
  // - (void)testDecodeBool {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(@NO, [serializer decode:@NO error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testEncodeString {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  XCTAssertEqualObjects(@"hello", [serializer encode:@"hello"]);
  // }
//
  // - (void)testDecodeString {
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(@"hello", [serializer decode:@"hello" error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testEncodeArray {
//  NSArray *input = @[ @1, @"two", @[ @3, @9876543210LL ] ];
//  NSArray *expected = @[
//    @1, @"two",
//    @[
//      @3, @{
//        @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//        @"value" : @"9876543210",
//      }
//    ]
//  ];
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  XCTAssertEqualObjects(expected, [serializer encode:input]);
  // }
//
  // - (void)testDecodeArray {
//  NSArray *input = @[
//    @1, @"two",
//    @[
//      @3, @{
//        @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//        @"value" : @"9876543210",
//      }
//    ]
//  ];
//  NSArray *expected = @[ @1, @"two", @[ @3, @9876543210LL ] ];
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//
//  XCTAssertEqualObjects(expected, [serializer decode:input error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testEncodeMap {
//  NSDictionary *input = @{@"foo" : @1, @"bar" : @"hello", @"baz" : @[ @3, @9876543210LL ]};
//  NSDictionary *expected = @{
//    @"foo" : @1,
//    @"bar" : @"hello",
//    @"baz" : @[
//      @3, @{
//        @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//        @"value" : @"9876543210",
//      }
//    ]
//  };
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  XCTAssertEqualObjects(expected, [serializer encode:input]);
  // }
//
  // - (void)testDecodeMap {
//  NSDictionary *input = @{
//    @"foo" : @1,
//    @"bar" : @"hello",
//    @"baz" : @[
//      @3, @{
//        @"@type" : @"type.googleapis.com/google.protobuf.Int64Value",
//        @"value" : @"9876543210",
//      }
//    ]
//  };
//  NSDictionary *expected = @{@"foo" : @1, @"bar" : @"hello", @"baz" : @[ @3, @9876543210LL ]};
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(expected, [serializer decode:input error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testDecodeUnknownType {
//  NSDictionary *input = @{@"@type" : @"unknown", @"value" : @"whatever"};
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(input, [serializer decode:input error:&error]);
//  XCTAssertNil(error);
  // }
//
  // - (void)testDecodeUnknownTypeWithoutValue {
//  NSDictionary *input = @{
//    @"@type" : @"unknown",
//  };
//  FUNSerializer *serializer = [[FUNSerializer alloc] init];
//  NSError *error = nil;
//  XCTAssertEqualObjects(input, [serializer decode:input error:&error]);
//  XCTAssertNil(error);
  // }
//
  // @end
}
