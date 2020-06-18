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

#import "FirebaseStorage/Sources/Public/FIRStorageMetadata.h"

#import "FirebaseStorage/Sources/Public/FIRStorageMetadata.h"

#import "FirebaseStorage/Sources/FIRStorageGetDownloadURLTask.h"
#import "FirebaseStorage/Sources/FIRStorageGetDownloadURLTask_Private.h"
#import "FirebaseStorage/Sources/FIRStorageMetadata_Private.h"
#import "FirebaseStorage/Sources/FIRStorageUtils.h"

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
    kFIRStorageMetadataGeneration : @"12345",
    kFIRStorageMetadataMetageneration : @"67890",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z",
    kFIRStorageMetadataUpdated : @"2016-03-01T20:16:01.673Z",
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
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
  XCTAssertEqualObjects(metadata.md5Hash, metaDict[kFIRStorageMetadataMd5Hash]);
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
    kFIRStorageMetadataGeneration : @"12345",
    kFIRStorageMetadataMetageneration : @"67890",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z",
    kFIRStorageMetadataUpdated : @"2016-03-01T20:16:01.673Z",
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
    kFIRStorageMetadataSize : @1337
  };
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  NSDictionary *dictRepresentation = [metadata dictionaryRepresentation];
  XCTAssertNotNil(dictRepresentation);
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
  XCTAssertEqualObjects(dictRepresentation[kFIRStorageMetadataMd5Hash],
                        metaDict[kFIRStorageMetadataMd5Hash]);
}

- (void)testInitializeEmptyDownloadURL {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  NSURL *actualURL = [FIRStorageGetDownloadURLTask downloadURLFromMetadataDictionary:metaDict];
  XCTAssertNil(actualURL);
}

- (void)testInitializeDownloadURLFromToken {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataDownloadTokens : @"12345,ignored",
    kFIRStorageMetadataName : @"path/to/object",
  };
  NSString *URLformat = @"https://firebasestorage.googleapis.com/v0/b/%@/o/%@?alt=media&token=%@";
  NSString *expectedURL = [NSString
      stringWithFormat:URLformat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       @"12345"];
  NSURL *actualURL = [FIRStorageGetDownloadURLTask downloadURLFromMetadataDictionary:metaDict];
  XCTAssertEqualObjects([actualURL absoluteString], expectedURL);
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
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
  };
  FIRStorageMetadata *metadata0 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  FIRStorageMetadata *metadata1 = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotEqual(metadata0, metadata1);
  XCTAssertEqualObjects(metadata0, metadata1);
}

- (void)testMetadataMd5Inequality {
  NSDictionary *firstDict = @{
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
  };
  NSDictionary *secondDict = @{
    kFIRStorageMetadataMd5Hash : @"foo",
  };
  FIRStorageMetadata *firstMetadata = [[FIRStorageMetadata alloc] initWithDictionary:firstDict];
  FIRStorageMetadata *secondMetadata = [[FIRStorageMetadata alloc] initWithDictionary:secondDict];
  XCTAssertNotEqualObjects(firstMetadata, secondMetadata);
}

- (void)testMetadataCopy {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
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

  NSDictionary *expectedUpdate = @{kFIRStorageMetadataCustomMetadata : @{}};
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
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z"};
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testZuluZeroTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108+0000"};
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testGoogleStandardTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108-0700"};
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testUnspecifiedTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108-0000"};
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testNoTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108"};
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNil(metadata.timeCreated);
}

@end
