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

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageMetadata.h"

#import "FirebaseStorageInternal/Sources/FIRStorageGetDownloadURLTask.h"
#import "FirebaseStorageInternal/Sources/FIRStorageGetDownloadURLTask_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageMetadata_Private.h"
#import "FirebaseStorageInternal/Sources/FIRStorageUtils.h"

#import "FirebaseStorageInternal/Tests/Unit/FIRStorageTestHelpers.h"

@interface FIRIMPLStorageMetadataTests : XCTestCase

@end

@implementation FIRIMPLStorageMetadataTests

- (void)testInitialzeNoMetadata {
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:@{}];
  XCTAssertNotNil(metadata);
}

- (void)testInitializeFullMetadata {
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
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
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
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRStorageGetDownloadURLTask *task =
      [[FIRStorageGetDownloadURLTask alloc] initWithReference:[FIRStorageTestHelpers rootReference]
                                               fetcherService:nil
                                                dispatchQueue:nil
                                                   completion:nil];
#pragma clang diagnostic pop
  NSURL *actualURL = [task downloadURLFromMetadataDictionary:metaDict];
  XCTAssertNil(actualURL);
}

- (void)testInitializeDownloadURLFromToken {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataDownloadTokens : @"12345,ignored",
    kFIRStorageMetadataName : @"path/to/object",
  };
  NSString *URLformat =
      @"https://firebasestorage.googleapis.com:443/v0/b/%@/o/%@?alt=media&token=%@";
  NSString *expectedURL = [NSString
      stringWithFormat:URLformat, metaDict[kFIRStorageMetadataBucket],
                       [FIRStorageUtils GCSEscapedString:metaDict[kFIRStorageMetadataName]],
                       @"12345"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  FIRStorageGetDownloadURLTask *task = [[FIRStorageGetDownloadURLTask alloc]
      initWithReference:[[FIRStorageTestHelpers rootReference] child:@"path/to/object"]
         fetcherService:nil
          dispatchQueue:nil
             completion:nil];
#pragma clang diagnostic pop
  NSURL *actualURL = [task downloadURLFromMetadataDictionary:metaDict];
  XCTAssertEqualObjects([actualURL absoluteString], expectedURL);
}

- (void)testInitialzeMetadataWithFile {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/file",
  };
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  [metadata setType:FIRStorageMetadataTypeFile];
  XCTAssertEqual(metadata.isFile, YES);
  XCTAssertEqual(metadata.isFolder, NO);
}

- (void)testInitialzeMetadataWithFolder {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/folder/",
  };
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  [metadata setType:FIRStorageMetadataTypeFolder];
  XCTAssertEqual(metadata.isFolder, YES);
  XCTAssertEqual(metadata.isFile, NO);
}

- (void)testReflexiveMetadataEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRIMPLStorageMetadata *metadata0 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  FIRIMPLStorageMetadata *metadata1 = metadata0;
  XCTAssertEqual(metadata0, metadata1);
  XCTAssertEqualObjects(metadata0, metadata1);
}

- (void)testNonsenseMetadataEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
  };
  FIRIMPLStorageMetadata *metadata0 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotEqualObjects(metadata0, @"I'm not object metadata!");
}

- (void)testMetadataEquality {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
  };
  FIRIMPLStorageMetadata *metadata0 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  FIRIMPLStorageMetadata *metadata1 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
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
  FIRIMPLStorageMetadata *firstMetadata =
      [[FIRIMPLStorageMetadata alloc] initWithDictionary:firstDict];
  FIRIMPLStorageMetadata *secondMetadata =
      [[FIRIMPLStorageMetadata alloc] initWithDictionary:secondDict];
  XCTAssertNotEqualObjects(firstMetadata, secondMetadata);
}

- (void)testMetadataCopy {
  NSDictionary *metaDict = @{
    kFIRStorageMetadataBucket : @"bucket",
    kFIRStorageMetadataName : @"path/to/object",
    kFIRStorageMetadataMd5Hash : @"d41d8cd98f00b204e9800998ecf8427e",
  };
  FIRIMPLStorageMetadata *metadata0 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  FIRIMPLStorageMetadata *metadata1 = [metadata0 copy];
  XCTAssertNotEqual(metadata0, metadata1);
  XCTAssertEqualObjects(metadata0, metadata1);
}

- (void)testUpdatedMetadata {
  NSDictionary *oldMetadata = @{
    kFIRStorageMetadataContentLanguage : @"old",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @"old", @"bar" : @"old"}
  };
  FIRIMPLStorageMetadata *metadata =
      [[FIRIMPLStorageMetadata alloc] initWithDictionary:oldMetadata];
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
  FIRIMPLStorageMetadata *metadata =
      [[FIRIMPLStorageMetadata alloc] initWithDictionary:oldMetadata];

  NSDictionary *update = [metadata updatedMetadata];

  NSDictionary *expectedUpdate = @{kFIRStorageMetadataCustomMetadata : @{}};
  XCTAssertEqualObjects(update, expectedUpdate);
}

- (void)testUpdatedMetadataWithDelete {
  NSDictionary *oldMetadata = @{
    kFIRStorageMetadataContentLanguage : @"old",
    kFIRStorageMetadataCustomMetadata : @{@"foo" : @"old", @"bar" : @"old"}
  };
  FIRIMPLStorageMetadata *metadata =
      [[FIRIMPLStorageMetadata alloc] initWithDictionary:oldMetadata];
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
  FIRIMPLStorageMetadata *metadata0 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  FIRIMPLStorageMetadata *metadata1 = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotEqual(metadata0, metadata1);
  XCTAssertEqual([metadata0 hash], [metadata1 hash]);
}

- (void)testZuluTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108Z"};
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testZuluZeroTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108+0000"};
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testGoogleStandardTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108-0700"};
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testUnspecifiedTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108-0000"};
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNotNil(metadata.timeCreated);
}

- (void)testNoTimeOffset {
  NSDictionary *metaDict = @{kFIRStorageMetadataTimeCreated : @"1992-08-07T17:22:53.108"};
  FIRIMPLStorageMetadata *metadata = [[FIRIMPLStorageMetadata alloc] initWithDictionary:metaDict];
  XCTAssertNil(metadata.timeCreated);
}

@end
