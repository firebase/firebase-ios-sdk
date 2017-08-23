// Copyright 2017 Google
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

#import "FIRStorageMetadata.h"
#import "FIRStorageMetadata_Private.h"
#import "FIRStorageUtils.h"

@interface FIRStorageMetadataTests : XCTestCase

@end

@implementation FIRStorageMetadataTests

- (void)testInitialzeNoMetadata {
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:@{}];
  XCTAssertNotNil(metadata);
}

- (void)testInitialzeFullMetadata {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataCacheControl : @"max-age=3600, no-cache",
    kFIRStorageMetadataContentDisposition : @"inline",
    kFIRStorageMetadataContentEncoding : @"gzip",
    kFIRStorageMetadataContentLanguage : @"en-us",
    kFIRStorageMetadataContentType : @"application/octet-stream",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @{@"bar" : @"baz"}},
    kFIRStorageMetadataDownloadTokens : @"1234567890",
    kFIRStorageMetadataGeneration : @"12345",
    kFIRStorageMetadataMetageneration : @"67890",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z",
    kFIRStorageMetadataUpdated : @"2016-03-01T20:16:01.673Z",
    kFIRStorageMetadataSize : @1337
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata);
  XCTAssertEqualObjects(metadata.bucket, metaDict[kFIRStorageMetadataBucket]);
  XCTAssertEqualObjects(metadata.cacheControl, metaDict[kFIRStorageMetadataCacheControl]);
  XCTAssertEqualObjects(metadata.contentDisposition,
                        metaDict[kFIRStorageMetadataContentDisposition]);
  XCTAssertEqualObjects(metadata.contentEncoding, metaDict[kFIRStorageMetadataContentEncoding], );
  XCTAssertEqualObjects(metadata.contentType, metaDict[kFIRStorageMetadataContentType]);
  XCTAssertEqualObjects(metadata.customMetadata, metaDict[kFIRStorageMetadataCustomMetadata]);
  NSString *URLFormat = @"https://firebasestorage.googleapis.com/v0/b/%@/o/%@?alt=media&token=%@";
  NSString *URLString = [NSString
      stringWithFormat:URLFormat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       metaDict[kFIRStorageMetadataDownloadTokens]];
  XCTAssertEqualObjects([metadata.downloadURL description], URLString);
  NSString *generation = [NSString stringWithFormat:@"%lld", metadata.generation];
  XCTAssertEqualObjects(generation, metaDict[kFIRStorageMetadataGeneration]);
  NSString *metageneration = [NSString stringWithFormat:@"%lld", metadata.metageneration];
  XCTAssertEqualObjects(metageneration, metaDict[kFIRStorageMetadataMetageneration]);
  XCTAssertEqualObjects(metadata.path, metaDict[kFIRStorageMetadataName]);
  XCTAssertEqualObjects([metadata RFC3339StringFromDate:metadata.timeCreated],
                        metaDict[kFIRStorageMetadataTimeCreated]);
  XCTAssertEqualObjects([metadata RFC3339StringFromDate:metadata.updated],
                        metaDict[kFIRStorageMetadataUpdated]);
  NSNumber *size = [NSNumber numberWithLongLong:metadata.size];
  XCTAssertEqualObjects(size, metaDict[kFIRStorageMetadataSize]);
}

- (void)testDictionaryRepresentation {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataCacheControl : @"max-age=3600, no-cache",
    kFIRStorageMetadataContentDisposition : @"inline",
    kFIRStorageMetadataContentEncoding : @"gzip",
    kFIRStorageMetadataContentLanguage : @"en-us",
    kFIRStorageMetadataContentType : @"application/octet-stream",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @{@"bar" : @"baz"}},
    kFIRStorageMetadataDownloadTokens : @"1234567890",
    kFIRStorageMetadataGeneration : @"12345",
    kFIRStorageMetadataMetageneration : @"67890",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z",
    kFIRStorageMetadataUpdated : @"2016-03-01T20:16:01.673Z",
    kFIRStorageMetadataSize : @1337
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  NSDictionary *dictRepresentation = [metadata dictionaryRepresentation];
  XCTAssertNotEqual(dictRepresentation, nil);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataBucket],
                        metaDict[kFIRStorageMetadataBucket]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataCacheControl],
                        metaDict[kFIRStorageMetadataCacheControl]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataContentDisposition],
                        metaDict[kFIRStorageMetadataContentDisposition]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataContentEncoding],
                        metaDict[kFIRStorageMetadataContentEncoding]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataContentLanguage],
                        metaDict[kFIRStorageMetadataContentLanguage]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataContentType],
                        metaDict[kFIRStorageMetadataContentType]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataCustomMetadata],
                        metaDict[kFIRStorageMetadataCustomMetadata]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataDownloadTokens],
                        metaDict[kFIRStorageMetadataDownloadTokens]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataGeneration],
                        metaDict[kFIRStorageMetadataGeneration]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataMetageneration],
                        metaDict[kFIRStorageMetadataMetageneration]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataName],
                        metaDict[kFIRStorageMetadataName]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataTimeCreated],
                        metaDict[kFIRStorageMetadataTimeCreated]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataUpdated],
                        metaDict[kFIRStorageMetadataUpdated]);
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataSize],
                        metaDict[kFIRStorageMetadataSize]);
}

- (void)testInitialzeNoDownloadTokensGetToken {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata);
  XCTAssertEqual(metadata.downloadURL, nil);
  XCTAssertEqual(metadata.downloadURLs, nil);
}

- (void)testInitialzeMultipleDownloadTokensGetToken {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataDownloadTokens : @"12345,67890",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata);
  NSString *URLformat = @"https://firebasestorage.googleapis.com/v0/b/%@/o/%@?alt=media&token=%@";
  NSString *URLString0 = [NSString
      stringWithFormat:URLformat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       @"12345"];
  NSString *URLString1 = [NSString
      stringWithFormat:URLformat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       @"67890"];
  XCTAssertEqualObjects([metadata.downloadURL absoluteString], URLString0);
  XCTAssertEqualObjects([metadata.downloadURLs[0] absoluteString], URLString0);
  XCTAssertEqualObjects([metadata.downloadURLs[1] absoluteString], URLString1);
}

- (void)testMultipleDownloadURLsGetToken {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  NSString *URLformat = @"https://firebasestorage.googleapis.com/v0/b/%@/o/%@?alt=media&token=%@";
  NSString *URLString0 = [NSString
      stringWithFormat:URLformat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       @"12345"];
  NSString *URLString1 = [NSString
      stringWithFormat:URLformat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       @"67890"];
  NSURL *URL0 = [NSURL URLWithString:URLString0];
  NSURL *URL1 = [NSURL URLWithString:URLString1];
  NSArray *downloadURLs = @[ URL0, URL1 ];
  [metadata setValue:downloadURLs forKey:@"downloadURLs"];
  NSDictionary *newMetaDict = metadata.dictionaryRepresentation;
  XCTAssertEqualObjects(newMetaDict[kFIRStorageMetadataDownloadTokens], @"12345,67890");
}

- (void)testInitialzeMetadataWithFile {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/file",
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  [metadata setType:FIRStorageMetadataTypeFile];
  XCTAssertEqual(metadata.isFile, YES);
  XCTAssertEqual(metadata.isFolder, NO);
}

- (void)testInitialzeMetadataWithFolder {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/folder/",
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  [metadata setType:FIRStorageMetadataTypeFolder];
  XCTAssertEqual(metadata.isFolder, YES);
  XCTAssertEqual(metadata.isFile, NO);
}

- (void)testReflexiveMetadataEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata0 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  FIRStorageMetadata *metadata1 = metadata0;
  XCTAssertEqual(metadata0, metadata1);
  XCTAssertEqualObjects(metadata0, metadata1);
}

- (void)testNonsenseMetadataEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata0 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotEqualObjects(metadata0, @"I'm not object metadata!");
}

- (void)testMetadataEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata0 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  FIRStorageMetadata *metadata1 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotEqual(metadata0, metadata1);
  XCTAssertEqualObjects(metadata0, metadata1);
}

- (void)testMetadataCopy {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata0 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  FIRStorageMetadata *metadata1 = [metadata0 copy];
  XCTAssertNotEqual(metadata0, metadata1);
  XCTAssertEqualObjects(metadata0, metadata1);
}

- (void)testUpdatedMetadata {
  NSDictionary *oldMetadata = @{
    kFIRStorageMetadataContentLanguage : @"old",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @"old", @"bar" : @"old"}
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:oldMetadata];
  metadata.contentLanguage = @"new";
  metadata.customMetadata = @{@"foo" : @"new", @"bar" : @"old"};

  NSDictionary *update = [metadata updatedMetadata];

  NSDictionary *expectedUpdate = @{
    kFIRStorageMetadataContentLanguage : @"new",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @"new"}
  };
  XCTAssertEqualObjects(update, expectedUpdate);
}

- (void)testUpdatedMetadataWithEmptyUpdate {
    NSDictionary *oldMetadata = @{
                                  kFIRStorageMetadataContentLanguage : @"old",
                                  kFIRStorageMetadataCustomMetadata : @{@"foo" : @"old", @"bar" : @"old"}
                                  };
    FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:oldMetadata];

    NSDictionary *update = [metadata updatedMetadata];

    NSDictionary *expectedUpdate = @{ kFIRStorageMetadataCustomMetadata : @{} };
    XCTAssertEqualObjects(update, expectedUpdate);
}

- (void)testUpdatedMetadataWithDelete {
  NSDictionary *oldMetadata = @{
    kFIRStorageMetadataContentLanguage : @"old",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @"old", @"bar" : @"old"}
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:oldMetadata];
  metadata.contentLanguage = nil;
  metadata.customMetadata = @{@"foo" : @"old"};

  NSDictionary *update = [metadata updatedMetadata];

  NSDictionary *expectedUpdate = @{
    kFIRStorageMetadataContentLanguage : [NSNull null],
    kFIRStorageMetadataCustomMetadata : @{@"bar" : [NSNull null]}
  };
  XCTAssertEqualObjects(update, expectedUpdate);
}

- (void)testMetadataHashEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRStorageMetadata *metadata0 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  FIRStorageMetadata *metadata1 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotEqual(metadata0, metadata1);
  XCTAssertEqual([metadata0 hash], [metadata1 hash]);
}

- (void)testZuluTimeOffset {
  NSDictionary *metaDict = @{ kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z" };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testZuluZeroTimeOffset {
  NSDictionary *metaDict = @{ kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108+0000" };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testGoogleStandardTimeOffset {
  NSDictionary *metaDict = @{ kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108-0700" };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testUnspecifiedTimeOffset {
  NSDictionary *metaDict = @{ kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108-0000" };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testNoTimeOffset {
  NSDictionary *metaDict = @{ kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108" };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNil(metadata.timeCreated);
}

@end
