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

#import <XCTest/XCTest.h>

#import "Firebase/Messaging/FIRMessagingCodedInputStream.h"

@interface FIRMessagingCodedInputStreamTest : XCTestCase
@end

@implementation FIRMessagingCodedInputStreamTest

- (void)testReadingSmallDataStream {
  FIRMessagingCodedInputStream *stream =
      [[FIRMessagingCodedInputStream alloc] initWithData:[[self class] sampleData1]];
  int8_t actualTag = 2;
  int8_t tag;
  XCTAssertTrue([stream readTag:&tag]);
  XCTAssertEqual(actualTag, tag);

  // test length
  int32_t actualLength = 4;
  int32_t length;
  XCTAssertTrue([stream readLength:&length]);
  XCTAssertEqual(actualLength, length);

  NSData *actualData = [[self class] packetDataForSampleData1];
  NSData *data = [stream readDataWithLength:length];
  XCTAssertTrue([actualData isEqualToData:data]);
}

- (void)testReadingLargeDataStream {
  FIRMessagingCodedInputStream *stream =
      [[FIRMessagingCodedInputStream alloc] initWithData:[[self class] sampleData2]];
  int8_t actualTag = 5;
  int8_t tag;
  XCTAssertTrue([stream readTag:&tag]);
  XCTAssertEqual(actualTag, tag);

  int32_t actualLength = 257;
  int32_t length;
  XCTAssertTrue([stream readLength:&length]);
  XCTAssertEqual(actualLength, length);

  NSData *actualData = [[self class] packetDataForSampleData2];
  NSData *data = [stream readDataWithLength:length];
  XCTAssertTrue([actualData isEqualToData:data]);
}

- (void)testReadingInvalidDataStream {
  FIRMessagingCodedInputStream *stream =
      [[FIRMessagingCodedInputStream alloc] initWithData:[[self class] invalidData]];
  int8_t actualTag = 7;
  int8_t tag;
  XCTAssertTrue([stream readTag:&tag]);
  XCTAssertEqual(actualTag, tag);

  int32_t actualLength = 2;
  int32_t length;
  XCTAssertTrue([stream readLength:&length]);
  XCTAssertEqual(actualLength, length);

  XCTAssertNil([stream readDataWithLength:length]);
}

+ (NSData *)sampleData1 {
  // tag = 2,
  // length = 4,
  // data = integer 255
  const char data[] = { 0x02, 0x04, 0x80, 0x00, 0x00, 0xff };
  return [NSData dataWithBytes:data length:6];
}

+ (NSData *)packetDataForSampleData1 {
  const char data[] = { 0x80, 0x00, 0x00, 0xff };
  return [NSData dataWithBytes:data length:4];
}

+ (NSData *)sampleData2 {
  // test reading varint properly
  // tag = 5,
  // length = 257,
  // data = length 257
  const char tagAndLength[] = { 0x05, 0x81, 0x02 };
  NSMutableData *data = [NSMutableData dataWithBytes:tagAndLength length:3];
  [data appendData:[self packetDataForSampleData2]];
  return data;
}

+ (NSData *)packetDataForSampleData2 {
  char packetData[257] = { 0xff, 0xff, 0xff };
  return [NSData dataWithBytes:packetData length:257];
}

+ (NSData *)invalidData {
  // tag = 7,
  // length = 2,
  // data = (length 1)
  const char data[] = { 0x07, 0x02, 0xff };
  return [NSData dataWithBytes:data length:3];
}

@end
