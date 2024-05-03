// Copyright 2019 Google
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

#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"

#if SWIFT_PACKAGE
@import FirebaseCrashlyticsSwift;
#else  // Swift Package Manager
#import <FirebaseCrashlytics/FirebaseCrashlytics-Swift.h>
#endif  // CocoaPods

#import <XCTest/XCTest.h>

@interface FIRCLSFileTests : XCTestCase

@property(nonatomic, assign) FIRCLSFile unbufferedFile;
@property(nonatomic, assign) FIRCLSFile bufferedFile;
@property(nonatomic, strong) NSString *unbufferedPath;
@property(nonatomic, strong) NSString *bufferedPath;

@end

@implementation FIRCLSFileTests

- (void)setUp {
  [super setUp];

  self.unbufferedPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"file_test"];
  self.bufferedPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"buffered_file_test"];

  [[NSFileManager defaultManager] removeItemAtPath:self.unbufferedPath error:nil];

  FIRCLSFileInitWithPathMode(&_unbufferedFile, [self.unbufferedPath fileSystemRepresentation],
                             false, false);
  FIRCLSFileInitWithPathMode(&_bufferedFile, [self.bufferedPath fileSystemRepresentation], false,
                             true);
}

- (void)tearDown {
  FIRCLSFileClose(&_unbufferedFile);
  FIRCLSFileClose(&_bufferedFile);

  [super tearDown];
}

- (NSString *)contentsOfFileAtPath:(NSString *)path {
  return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark -

- (void)testEmptySection {
  [self emptySectionWithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self emptySectionWithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)emptySectionWithFile:(FIRCLSFile *)file
                    filePath:(NSString *)filePath
                    buffered:(BOOL)buffered {
  FIRCLSFileWriteSectionStart(file, "empty");
  FIRCLSFileWriteSectionEnd(file);
  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(
      contents, @"{\"empty\":}\n",
      @"Empty written to and retrieved from file does not match input in %@buffered case",
      buffered ? @"" : @"un");
}

#pragma mark -

- (void)testSingleArrayCollection {
  [self singleArrayCollectionWithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self singleArrayCollectionWithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)singleArrayCollectionWithFile:(FIRCLSFile *)file
                             filePath:(NSString *)filePath
                             buffered:(BOOL)buffered {
  FIRCLSFileWriteSectionStart(file, "array");
  FIRCLSFileWriteArrayStart(file);
  FIRCLSFileWriteArrayEntryUint64(file, 1);
  FIRCLSFileWriteArrayEnd(file);
  FIRCLSFileWriteSectionEnd(file);
  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(
      contents, @"{\"array\":[1]}\n",
      @"Single array written to and retrieved from file does not match input in %@buffered case",
      buffered ? @"" : @"un");
}

#pragma mark -

- (void)testEmptyCollectionFollowedByEntry {
  [self emptyCollectionFollowedByEntryWithFile:&_unbufferedFile
                                      filePath:self.unbufferedPath
                                      buffered:NO];
  [self emptyCollectionFollowedByEntryWithFile:&_bufferedFile
                                      filePath:self.bufferedPath
                                      buffered:YES];
}

- (void)emptyCollectionFollowedByEntryWithFile:(FIRCLSFile *)file
                                      filePath:(NSString *)filePath
                                      buffered:(BOOL)buffered {
  FIRCLSFileWriteSectionStart(file, "empty_array");
  FIRCLSFileWriteArrayStart(file);
  FIRCLSFileWriteArrayEnd(file);

  // and now put in another entry into the hash
  FIRCLSFileWriteHashEntryUint64(file, "value", 1);
  FIRCLSFileWriteSectionEnd(file);
  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(contents, @"{\"empty_array\":[],\"value\":1}\n",
                        @"Empty collection and entry written to and retrieved from file does not "
                        @"match input in %@buffered case",
                        buffered ? @"" : @"un");
}

#pragma mark -

- (void)testHexEncodingString {
  [self hexEncodingStringWithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self hexEncodingStringWithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)hexEncodingStringWithFile:(FIRCLSFile *)file
                         filePath:(NSString *)filePath
                         buffered:(BOOL)buffered {
  FIRCLSFileWriteHashStart(file);
  FIRCLSFileWriteHashEntryHexEncodedString(file, "hex", "hex string");
  FIRCLSFileWriteHashEnd(file);
  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(contents, @"{\"hex\":\"68657820737472696e67\"}",
                        @"Hex encoded string written to and retrieved from file does not match "
                        @"input in %@buffered case",
                        buffered ? @"" : @"un");
}

// This is the test to compare FIRCLSwiftFileUtility.stringToHexConverter(for:) and
// FIRCLSFileWriteHexEncodedString return the same hex encoding value
- (void)testHexEncodingStringObjcAndSwiftResultsSame {
  NSString *testedValueString = @"是themis的测试数据，输入中文";

  FIRCLSFile *unbufferedFile = &_unbufferedFile;
  FIRCLSFileWriteHashStart(unbufferedFile);
  FIRCLSFileWriteHashEntryHexEncodedString(unbufferedFile, "hex", [testedValueString UTF8String]);
  FIRCLSFileWriteHashEnd(unbufferedFile);
  NSString *contentsFromObjcHexEncoding = [self contentsOfFileAtPath:self.unbufferedPath];

  FIRCLSFile *bufferedFile = &_bufferedFile;
  NSString *encodedValue = [FIRCLSwiftFileUtility stringToHexConverterFor:testedValueString];
  FIRCLSFileWriteHashStart(bufferedFile);
  FIRCLSFileWriteHashKey(bufferedFile, "hex");
  FIRCLSFileWriteStringUnquoted(bufferedFile, "\"");
  FIRCLSFileWriteStringUnquoted(bufferedFile, [encodedValue UTF8String]);
  FIRCLSFileWriteStringUnquoted(bufferedFile, "\"");
  FIRCLSFileWriteHashEnd(bufferedFile);
  FIRCLSFileFlushWriteBuffer(bufferedFile);
  NSString *contentsFromSwiftHexEncoding = [self contentsOfFileAtPath:self.bufferedPath];

  XCTAssertTrue([contentsFromObjcHexEncoding isEqualToString:contentsFromSwiftHexEncoding]);
}

#pragma mark -

- (void)testHexEncodingLongString {
  [self hexEncodingLongStringWithFile:&_unbufferedFile
                             filePath:self.unbufferedPath
                               length:CLS_FILE_HEX_BUFFER * 10
                             buffered:NO];
  [self hexEncodingLongStringWithFile:&_bufferedFile
                             filePath:self.bufferedPath
                               length:FIRCLSWriteBufferLength * 10
                             buffered:YES];
}

- (void)hexEncodingLongStringWithFile:(FIRCLSFile *)file
                             filePath:(NSString *)filePath
                               length:(size_t)length
                             buffered:(BOOL)buffered {
  char *longString = malloc(length * sizeof(char));

  memset(longString, 'a', length);  // fill it with 'a' characters
  longString[length - 1] = 0;       // null terminate

  FIRCLSFileWriteHashStart(file);
  FIRCLSFileWriteHashEntryHexEncodedString(file, "hex", longString);
  FIRCLSFileWriteHashEnd(file);

  NSDictionary *dict =
      [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filePath]
                                      options:0
                                        error:nil];

  if (buffered) {
    XCTAssertNil(dict);
    FIRCLSFileFlushWriteBuffer(file);
    dict = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filePath]
                                           options:0
                                             error:nil];
  }

  XCTAssertNotNil(dict,
                  @"Expected a dictionary serialized from JSON file contents in %@buffered case",
                  buffered ? @"" : @"un");
  XCTAssertEqual([dict[@"hex"] length], (length - 1) * 2,
                 @"Long hex encoded string written to and retrieved from file does not match input "
                 @"in %@buffered case",
                 buffered ? @"" : @"un");

  free(longString);
}

#pragma mark -

- (void)testSignedInteger {
  [self signedIntegerWithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self signedIntegerWithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)signedIntegerWithFile:(FIRCLSFile *)file
                     filePath:(NSString *)filePath
                     buffered:(BOOL)buffered {
  FIRCLSFileWriteSectionStart(file, "signed");
  FIRCLSFileWriteHashStart(file);
  FIRCLSFileWriteHashEntryInt64(file, "value", -1);
  FIRCLSFileWriteHashEnd(file);
  FIRCLSFileWriteSectionEnd(file);

  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(
      contents, @"{\"signed\":{\"value\":-1}}\n",
      @"Signed integer written to and retrieved from file does not match input in %@buffered case",
      buffered ? @"" : @"un");
}

#pragma mark -

- (void)testBigInteger {
  [self bigIntegerWithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self bigIntegerWithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)bigIntegerWithFile:(FIRCLSFile *)file
                  filePath:(NSString *)filePath
                  buffered:(BOOL)buffered {
  FIRCLSFileWriteSectionStart(file, "big_int");
  FIRCLSFileWriteHashStart(file);
  FIRCLSFileWriteHashEntryUint64(file, "value", 0x12345678900af8a1);
  FIRCLSFileWriteHashEnd(file);
  FIRCLSFileWriteSectionEnd(file);

  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(
      contents, @"{\"big_int\":{\"value\":1311768467284359329}}\n",
      @"Big integer written to and retrieved from file does not match input in %@buffered case",
      buffered ? @"" : @"un");
}

#pragma mark -

- (void)testMaxUInt64 {
  [self maxUInt64WithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self maxUInt64WithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)maxUInt64WithFile:(FIRCLSFile *)file filePath:(NSString *)filePath buffered:(BOOL)buffered {
  FIRCLSFileWriteSectionStart(file, "big_int");
  FIRCLSFileWriteHashStart(file);
  FIRCLSFileWriteHashEntryUint64(file, "value", 0xFFFFFFFFFFFFFFFF);
  FIRCLSFileWriteHashEnd(file);
  FIRCLSFileWriteSectionEnd(file);

  NSString *contents = [self contentsOfFileAtPath:filePath];
  if (buffered) {
    XCTAssertEqualObjects(
        contents, @"",
        @"Expected empty file contents for buffered case: buffer has not yet been flushed to file");
    FIRCLSFileFlushWriteBuffer(file);
    contents = [self contentsOfFileAtPath:filePath];
  }
  XCTAssertEqualObjects(contents, @"{\"big_int\":{\"value\":18446744073709551615}}\n",
                        @"Max unsigned integer written to and retrieved from file does not match "
                        @"input in %@buffered case",
                        buffered ? @"" : @"un");
}

#pragma mark -

- (void)testSimpleHashPerformanceWithUnbufferedFile {
  [self measureBlock:^{
    // just one run isn't sufficient
    for (NSUInteger i = 0; i < 2000; ++i) {
      FIRCLSFileWriteSectionStart(&self->_unbufferedFile, "hash_test");
      FIRCLSFileWriteHashEntryString(&self->_unbufferedFile, "key1", "value1");
      FIRCLSFileWriteHashEntryUint64(&self->_unbufferedFile, "key2", 64);
      FIRCLSFileWriteHashEntryNSString(&self->_unbufferedFile, "key2", @"some string");
      FIRCLSFileWriteSectionEnd(&self->_unbufferedFile);
    }
  }];
}

- (void)testSimpleHashPerformanceWithBufferedFile {
  [self measureBlock:^{
    // just one run isn't sufficient
    for (NSUInteger i = 0; i < 2000; ++i) {
      FIRCLSFileWriteSectionStart(&self->_bufferedFile, "hash_test");
      FIRCLSFileWriteHashEntryString(&self->_bufferedFile, "key1", "value1");
      FIRCLSFileWriteHashEntryUint64(&self->_bufferedFile, "key2", 64);
      FIRCLSFileWriteHashEntryNSString(&self->_bufferedFile, "key2", @"some string");
      FIRCLSFileWriteSectionEnd(&self->_bufferedFile);
    }
  }];
}

#pragma mark -

- (void)testOpenAndClose {
  [self openAndCloseWithFile:&_unbufferedFile filePath:self.unbufferedPath buffered:NO];
  [self openAndCloseWithFile:&_bufferedFile filePath:self.bufferedPath buffered:YES];
}

- (void)openAndCloseWithFile:(FIRCLSFile *)file
                    filePath:(NSString *)filePath
                    buffered:(BOOL)buffered {
  XCTAssert(FIRCLSFileIsOpen(file), @"File should be opened by setup in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileClose(file), @"Closing the file should succeed in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssertFalse(FIRCLSFileIsOpen(file), @"File should now be marked as closed in %@buffered case",
                 buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileInitWithPath(file, [filePath fileSystemRepresentation], buffered),
            @"Re-opening the same file structure should succeed in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileIsOpen(file),
            @"That file should be marked as open as well in %@buffered case",
            buffered ? @"" : @"un");
}

#pragma mark -

- (void)testCloseAndOpenAlternatingBufferedOption {
  [self closeAndOpenAlternatingBufferedOptionWithFile:&_unbufferedFile
                                             filePath:self.unbufferedPath
                                             buffered:NO];
  [self closeAndOpenAlternatingBufferedOptionWithFile:&_bufferedFile
                                             filePath:self.bufferedPath
                                             buffered:YES];
}

- (void)closeAndOpenAlternatingBufferedOptionWithFile:(FIRCLSFile *)file
                                             filePath:(NSString *)filePath
                                             buffered:(BOOL)buffered {
  XCTAssert(FIRCLSFileIsOpen(file), @"File should be opened by setup in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileClose(file), @"Closing the file should succeed in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssertFalse(FIRCLSFileIsOpen(file), @"File should now be marked as closed in %@buffered case",
                 buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileInitWithPath(file, [filePath fileSystemRepresentation], !buffered),
            @"Re-opening the same file structure should succeed in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileIsOpen(file),
            @"That file should be marked as open as well in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileClose(file), @"Closing the file should succeed in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssertFalse(FIRCLSFileIsOpen(file), @"File should now be marked as closed in %@buffered case",
                 buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileInitWithPath(file, [filePath fileSystemRepresentation], buffered),
            @"Re-opening the same file structure should succeed in %@buffered case",
            buffered ? @"" : @"un");
  XCTAssert(FIRCLSFileIsOpen(file),
            @"That file should be marked as open as well in %@buffered case",
            buffered ? @"" : @"un");
}

#pragma mark -

- (void)testLoggingInputLongerThanBuffer {
  size_t inputLength = (FIRCLSWriteBufferLength + 2) * sizeof(char);
  char *input = malloc(inputLength);
  for (size_t i = 0; i < inputLength - 1; i++) {
    input[i] = i % 26 + 'a';
  }
  input[inputLength - 1] = '\0';
  NSString *inputString = [NSString stringWithUTF8String:input];

  FIRCLSFileWriteHashStart(&_bufferedFile);
  FIRCLSFileWriteHashEntryString(&_bufferedFile, "value", input);
  FIRCLSFileWriteHashEnd(&_bufferedFile);
  FIRCLSFileFlushWriteBuffer(&_bufferedFile);

  NSError *error;
  NSDictionary *dict =
      [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:self.bufferedPath]
                                      options:0
                                        error:&error];
  XCTAssertNotNil(dict,
                  @"No data was retrieved from log file while writing long input with buffering");
  NSString *writtenValue = dict[@"value"];
  XCTAssertEqualObjects(inputString, writtenValue,
                        @"Data was lost while writing long input to file with write buffering");

  free(input);
}

@end
