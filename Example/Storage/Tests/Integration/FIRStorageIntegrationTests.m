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

#import <math.h>
#import <XCTest/XCTest.h>

#import "FirebaseStorage.h"

#import "FIRApp.h"
#import "FIROptions.h"

NSTimeInterval kFIRStorageIntegrationTestTimeout = 30;

/**
 * Firebase Storage Integration tests
 *
 * To run these tests, you need to define the following access rights for your Firebase App:
 * - unauthentication read/write access to /ios/public
 * - authentication read/write access to /ios/private
 *
 * A sample configuration may look like:
 *
 * service firebase.storage {
 *   match /b/{YOUR_PROJECT_ID}.appspot.com/o {
 *     ...
 *     match /ios {
 *       match /public/{allPaths=**} {
 *         allow read, write;
 *       }
 *       match /private/{allPaths=**} {
 *         allow none;
 *       }
 *     }
 *   }
 * }
 *
 * You can define these access rights in the Firebase Console of your project.
 */
@interface FIRStorageIntegrationTests : XCTestCase

@property(strong, nonatomic) FIRApp *app;
@property(strong, nonatomic) FIRStorage *storage;

@end

@implementation FIRStorageIntegrationTests


+ (void)setUp {
    [FIRApp configure];
}

- (void)setUp {
    [super setUp];

    self.app = [FIRApp defaultApp];
    self.storage = [FIRStorage storageForApp:self.app];

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        XCTestExpectation *expectation = [self expectationWithDescription:@"setup"];

        FIRStorageReference *ref = [[FIRStorage storage].reference child:@"ios/public/1mb"];
        NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"1mb" ofType:@"dat"]];
        XCTAssertNotNil(data, "Could not load bundled file");
        [ref putData:data metadata:nil completion:^(FIRStorageMetadata *metadata, NSError *error) {
            XCTAssertNil(error);
            [expectation fulfill];
        }];

        [self waitForExpectations];
    });
}

- (void)tearDown {
    self.app = nil;
    self.storage = nil;

    [super tearDown];
}

- (void)testName {
    NSString *aGSURI = [NSString stringWithFormat:@"gs://%@.appspot.com/path/to", [[FIRApp defaultApp] options].projectID];
    FIRStorageReference *ref = [self.storage referenceForURL:aGSURI];
    XCTAssertEqualObjects(ref.description, aGSURI);
}

- (void)testUnauthenticatedGetMetadata {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedGetMetadata"];
    FIRStorageReference *ref = [self.storage.reference child:@"ios/public/1mb"];

    [ref metadataWithCompletion:^(FIRStorageMetadata *metadata, NSError *error) {
        XCTAssertNotNil(metadata, "Metadata should not be nil");
        XCTAssertNil(error, "Error should be nil");
        [expectation fulfill];
    }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedUpdateMetadata {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedUpdateMetadata"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

    FIRStorageMetadata *meta = [[FIRStorageMetadata alloc] init];
    [meta setContentType:@"lol/custom"];
    [meta setCustomMetadata:@{
                              @"lol" : @"custom metadata is neat",
                              @"ちかてつ" : @"🚇",
                              @"shinkansen" : @"新幹線"
                              }];

    [ref updateMetadata:meta
             completion:^(FIRStorageMetadata *metadata, NSError *error) {
                 XCTAssertEqualObjects(meta.contentType, metadata.contentType);
                 XCTAssertEqualObjects(meta.customMetadata[@"lol"],
                                       metadata.customMetadata[@"lol"]);
                 XCTAssertEqualObjects(meta.customMetadata[@"ちかてつ"],
                                       metadata.customMetadata[@"ちかてつ"]);
                 XCTAssertEqualObjects(meta.customMetadata[@"shinkansen"],
                                       metadata.customMetadata[@"shinkansen"]);
                 XCTAssertNil(error, "Error should be nil");
                 [expectation fulfill];
             }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedDelete {
    XCTestExpectation *expectation = [self expectationWithDescription:@"testUnauthenticatedDelete"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/fileToDelete"];

    NSData *data = [@"Delete me!!!!!!!" dataUsingEncoding:NSUTF8StringEncoding];

    [ref putData:data
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [ref deleteWithCompletion:^(NSError *error) {
              XCTAssertNil(error, "Error should be nil");
              [expectation fulfill];
          }];
      }];

    [self waitForExpectations];
}

- (void)testDeleteWithNilCompletion {
    XCTestExpectation *expectation = [self expectationWithDescription:@"testDeleteWithNilCompletion"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/fileToDelete"];

    NSData *data = [@"Delete me!!!!!!!" dataUsingEncoding:NSUTF8StringEncoding];

    [ref putData:data
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [ref deleteWithCompletion:nil];
          [expectation fulfill];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimplePutData {
    XCTestExpectation *expectation =
    [self expectationWithDescription:@"testUnauthenticatedSimplePutData"];
    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/testBytesUpload"];

    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];

    [ref putData:data
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [expectation fulfill];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimplePutEmptyData {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimplePutEmptyData"];

    FIRStorageReference *ref =
      [self.storage referenceWithPath:@"ios/public/testUnauthenticatedSimplePutEmptyData"];

    NSData *data = [[NSData alloc] init];

    [ref putData:data
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [expectation fulfill];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimplePutDataUnauthorized {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimplePutDataUnauthorized"];
    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/private/secretfile.txt"];

    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];

    [ref putData:data
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNil(metadata, "Metadata should be nil");
          XCTAssertNotNil(error, "Error should not be nil");
          XCTAssertEqual(error.code, FIRStorageErrorCodeUnauthorized);
          [expectation fulfill];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimplePutFile {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimplePutFile"];

    FIRStorageReference *ref =
      [self.storage referenceWithPath:@"ios/public/testUnauthenticatedSimplePutFile"];

    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL =
    [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"txt"];
    [data writeToURL:fileURL atomically:YES];

    FIRStorageUploadTask *task = [ref putFile:fileURL
                                     metadata:nil
                                   completion:^(FIRStorageMetadata *metadata, NSError *error) {
                                       XCTAssertNotNil(metadata, "Metadata should not be nil");
                                       XCTAssertNil(error, "Error should be nil");
                                   }];

    __block long uploadedBytes = -1;

    [task observeStatus:FIRStorageTaskStatusSuccess
                handler:^(FIRStorageTaskSnapshot *snapshot) {
                    XCTAssertEqualObjects([snapshot description], @"<State: Success>");
                    [expectation fulfill];
                }];

    [task observeStatus:FIRStorageTaskStatusProgress
                handler:^(FIRStorageTaskSnapshot *_Nonnull snapshot) {
                    XCTAssertTrue([[snapshot description] containsString:@"State: Progress"] ||
                                  [[snapshot description] containsString:@"State: Resume"]);
                    NSProgress *progress = snapshot.progress;
                    XCTAssertGreaterThanOrEqual(progress.completedUnitCount, uploadedBytes);
                    uploadedBytes = progress.completedUnitCount;
                }];

    [self waitForExpectations];
}

- (void)testPutFileWithSpecialCharacters {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testPutFileWithSpecialCharacters"];

    NSString *fileName = @"hello&+@_ .txt";
    FIRStorageReference *ref =
    [self.storage referenceWithPath:[@"ios/public/" stringByAppendingString:fileName]];

    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tmpDirURL URLByAppendingPathComponent:fileName];
    [data writeToURL:fileURL atomically:YES];

    [ref putFile:fileURL
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          XCTAssertEqualObjects(fileName, metadata.name);
          FIRStorageReference *download =
          [self.storage referenceWithPath:[@"ios/public/" stringByAppendingString:fileName]];
          [download metadataWithCompletion:^(FIRStorageMetadata *metadata, NSError *error) {
              XCTAssertNotNil(metadata, "Metadata should not be nil");
              XCTAssertNil(error, "Error should be nil");
              XCTAssertEqualObjects(fileName, metadata.name);
              [expectation fulfill];
          }];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimplePutDataNoMetadata {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimplePutDataNoMetadata"];

    FIRStorageReference *ref =
      [self.storage referenceWithPath:@"ios/public/testUnauthenticatedSimplePutDataNoMetadata"];

    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];

    [ref putData:data
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [expectation fulfill];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimplePutFileNoMetadata {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimplePutFileNoMetadata"];

    FIRStorageReference *ref =
      [self.storage referenceWithPath:@"ios/public/testUnauthenticatedSimplePutFileNoMetadata"];

    NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL =
    [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"txt"];
    [data writeToURL:fileURL atomically:YES];

    [ref putFile:fileURL
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [expectation fulfill];
      }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimpleGetData {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimpleGetData"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

    [ref dataWithMaxSize:1 * 1024 * 1024
              completion:^(NSData *data, NSError *error) {
                  XCTAssertNotNil(data, "Data should not be nil");
                  XCTAssertNil(error, "Error should be nil");
                  [expectation fulfill];
              }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimpleGetDataTooSmall {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimpleGetDataTooSmall"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

    /// Only allow 1kB size, which is smaller than our file
    [ref dataWithMaxSize:1 * 1024
              completion:^(NSData *data, NSError *error) {
                  XCTAssertEqual(data, nil);
                  XCTAssertEqual(error.code, FIRStorageErrorCodeDownloadSizeExceeded);
                  [expectation fulfill];
              }];

    [self waitForExpectations];
}

- (void)testUnauthenticatedSimpleGetFile {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedSimpleGetData"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/helloworld"];

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL =
      [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"txt"];

    [ref putData:[@"Hello World" dataUsingEncoding:NSUTF8StringEncoding] metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error)
    {
        FIRStorageDownloadTask *task = [ref writeToFile:fileURL];

        [task observeStatus:FIRStorageTaskStatusSuccess
                    handler:^(FIRStorageTaskSnapshot *snapshot) {
                        NSString *data = [NSString stringWithContentsOfURL:fileURL
                                                                  encoding:NSUTF8StringEncoding
                                                                     error:NULL];
                        NSString *expectedData = @"Hello World";
                        XCTAssertEqualObjects(data, expectedData);
                        XCTAssertEqualObjects([snapshot description], @"<State: Success>");
                        [expectation fulfill];
                    }];

        [task observeStatus:FIRStorageTaskStatusProgress
                    handler:^(FIRStorageTaskSnapshot *_Nonnull snapshot) {
                        NSProgress *progress = snapshot.progress;
                        NSLog(@"%lld of %lld", progress.completedUnitCount, progress.totalUnitCount);
                    }];

        [task observeStatus:FIRStorageTaskStatusFailure
                    handler:^(FIRStorageTaskSnapshot *snapshot) {
                        XCTAssertNil(snapshot.error);
                        [expectation fulfill];
                    }];
    }];

    [self waitForExpectations];
}

- (void)testCancelDownload {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testCancelDownload"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL =
        [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"dat"];

    FIRStorageDownloadTask *task = [ref writeToFile:fileURL];

    [task observeStatus:FIRStorageTaskStatusFailure
                handler:^(FIRStorageTaskSnapshot *snapshot) {
                    XCTAssertTrue([[snapshot description] containsString:@"State: Failed"]);
                    [expectation fulfill];
                }];

    [task observeStatus:FIRStorageTaskStatusProgress
                handler:^(FIRStorageTaskSnapshot *_Nonnull snapshot) {
                    [task cancel];
                }];

    [self waitForExpectations];
}

- (void)assertMetadata:(FIRStorageMetadata *) actualMetadata
           contentType:(NSString *) expectedContentType
        customMetadata:(NSDictionary *) expectedCustomMetadata {
  XCTAssertEqualObjects(actualMetadata.cacheControl, @"cache-control");
  XCTAssertEqualObjects(actualMetadata.contentDisposition, @"content-disposition");
  XCTAssertEqualObjects(actualMetadata.contentEncoding, @"gzip");
  XCTAssertEqualObjects(actualMetadata.contentLanguage, @"de");
  XCTAssertEqualObjects(actualMetadata.contentType, expectedContentType);
  for (NSString* key in expectedCustomMetadata) {
    XCTAssertEqualObjects([actualMetadata.customMetadata objectForKey:key],
                          [expectedCustomMetadata objectForKey:key]);
  }
}

- (void)assertMetadataNil:(FIRStorageMetadata *) actualMetadata {
    XCTAssertNil(actualMetadata.cacheControl);
    XCTAssertNil(actualMetadata.contentDisposition);
    XCTAssertEqualObjects(actualMetadata.contentEncoding, @"identity");
    XCTAssertNil(actualMetadata.contentLanguage);
    XCTAssertNil(actualMetadata.contentType);
    XCTAssertNil([actualMetadata.customMetadata objectForKey:@"a"]);
    XCTAssertNil([actualMetadata.customMetadata objectForKey:@"c"]);
    XCTAssertNil([actualMetadata.customMetadata objectForKey:@"f"]);
}

- (void)testUpdateMetadata {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateMetadata"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

  // Update all available metadata
  FIRStorageMetadata *metadata = [[FIRStorageMetadata alloc] init];
  metadata.cacheControl = @"cache-control";
  metadata.contentDisposition = @"content-disposition";
  metadata.contentEncoding = @"gzip";
  metadata.contentLanguage = @"de";
  metadata.contentType = @"content-type-a";
  metadata.customMetadata = @{@"a" : @"b"};

  [ref updateMetadata:metadata completion:^(FIRStorageMetadata *updatedMetadata, NSError *error) {
      XCTAssertNil(error);
      [self assertMetadata:updatedMetadata contentType:@"content-type-a" customMetadata:@{@"a" : @"b"}];

      // Update a subset of the metadata using the existing object.
      FIRStorageMetadata *metadata = updatedMetadata;
      metadata.contentType = @"content-type-b";
      metadata.customMetadata = @{@"a" : @"b", @"c" : @"d"};

      [ref updateMetadata:metadata completion:^(FIRStorageMetadata *updatedMetadata, NSError *error) {
          XCTAssertNil(error);
          [self assertMetadata:updatedMetadata contentType:@"content-type-b" customMetadata: @{@"a" : @"b", @"c" : @"d"}];

          // Clear all metadata.
          FIRStorageMetadata *metadata = updatedMetadata;
          metadata.cacheControl = nil;
          metadata.contentDisposition = nil;
          metadata.contentEncoding = nil;
          metadata.contentLanguage = nil;
          metadata.contentType = nil;
          metadata.customMetadata = [NSDictionary dictionary];

          [ref updateMetadata:metadata completion:^(FIRStorageMetadata *updatedMetadata, NSError *error) {
              XCTAssertNil(error);
              [self assertMetadataNil:updatedMetadata];
              [expectation fulfill];
          }];
      }];
   }];

  [self waitForExpectations];
}

- (void)testUnauthenticatedResumeGetFile {
    XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedResumeGetFile"];

    FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

    NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL =
    [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"txt"];

    __block long resumeAtBytes = 256 * 1024;
    __block long downloadedBytes = 0;
    __block double computationResult = 0;

    FIRStorageDownloadTask *task = [ref writeToFile:fileURL];

    [task observeStatus:FIRStorageTaskStatusSuccess
                handler:^(FIRStorageTaskSnapshot *snapshot) {
                    XCTAssertEqualObjects([snapshot description], @"<State: Success>");
                    [expectation fulfill];
                }];

    [task observeStatus:FIRStorageTaskStatusProgress
                handler:^(FIRStorageTaskSnapshot *_Nonnull snapshot) {
                    XCTAssertTrue([[snapshot description] containsString:@"State: Progress"] ||
                                  [[snapshot description] containsString:@"State: Resume"]);
                    NSProgress *progress = snapshot.progress;
                    XCTAssertGreaterThanOrEqual(progress.completedUnitCount, downloadedBytes);
                    downloadedBytes = progress.completedUnitCount;
                    if (progress.completedUnitCount > resumeAtBytes) {
                        // Making sure the main run loop is busy.
                        for (int i = 0; i < 500; ++i) {
                            dispatch_async(dispatch_get_main_queue(), ^ {
                                computationResult = sqrt(INT_MAX - i);
                            });
                        }
                        NSLog(@"Pausing");
                        [task pause];
                        resumeAtBytes = INT_MAX;
                    }
                }];

    [task observeStatus:FIRStorageTaskStatusPause
                handler:^(FIRStorageTaskSnapshot *snapshot) {
                    XCTAssertEqualObjects([snapshot description], @"<State: Paused>");
                    NSLog(@"Resuming");
                    [task resume];
                }];

    [self waitForExpectations];
    XCTAssertEqual(INT_MAX, resumeAtBytes);
    XCTAssertEqualWithAccuracy(sqrt(INT_MAX - 499), computationResult, 0.1);
}

- (void)waitForExpectations {
    [self waitForExpectationsWithTimeout:kFIRStorageIntegrationTestTimeout
                                 handler:^(NSError *_Nullable error) {
                                     if (error) {
                                         NSLog(@"%@", error);
                                     }
                                 }];
}

@end
