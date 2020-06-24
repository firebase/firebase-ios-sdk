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

#import "FirebaseStorage/Sources/Public/FirebaseStorage.h"

#import <FirebaseAuth/FirebaseAuth.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseStorage/Tests/Integration/Credentials.h"

NSTimeInterval kFIRStorageIntegrationTestTimeout = 60;

/**
 * Firebase Storage Integration tests
 *
 * To run these tests, you need to define the following access rights:
 *
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /{directChild=*} {
        allow read: if request.auth != null;
      }
      match /ios {
        match /public/{allPaths=**} {
          allow write: if request.auth != null;
          allow read: if true;
        }
        match /private/{allPaths=**} {
          allow read, write: if false;
        }
      }
    }
  }
 *
 * You also need to enable email/password sign in and add a test user in your
 * Firebase Authentication settings. Your account credentials need to match
 * the credentials defined in `kTestUser` and `kTestPassword`.
 *
 * You can define these access rights in the Firebase Console of your project.
 */

NSString *const kTestUser = KUSER_NAME;
NSString *const kTestPassword = KPASSWORD;

@interface FIRStorageIntegrationTests : XCTestCase

@property(strong, nonatomic) FIRApp *app;
@property(strong, nonatomic) FIRAuth *auth;
@property(strong, nonatomic) FIRStorage *storage;

@end

@implementation FIRStorageIntegrationTests

+ (void)setUp {
  [FIRApp configure];
}

- (void)setUp {
  [super setUp];

  self.app = [FIRApp defaultApp];
  self.auth = [FIRAuth authWithApp:self.app];
  self.storage = [FIRStorage storageForApp:self.app];

  static dispatch_once_t once;
  dispatch_once(&once, ^{
    XCTestExpectation *signInExpectation = [self expectationWithDescription:@"signIn"];
    [self.auth signInWithEmail:kTestUser
                      password:kTestPassword
                    completion:^(FIRAuthDataResult *result, NSError *error) {
                      XCTAssertNil(error);
                      [signInExpectation fulfill];
                    }];
    [self waitForExpectations];

    XCTestExpectation *setUpExpectation = [self expectationWithDescription:@"setUp"];

    NSArray<NSString *> *largeFiles = @[ @"ios/public/1mb" ];
    NSArray<NSString *> *emptyFiles = @[
      @"ios/public/empty", @"ios/public/list/a", @"ios/public/list/b", @"ios/public/list/prefix/c"
    ];
    setUpExpectation.expectedFulfillmentCount = largeFiles.count + emptyFiles.count;

    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"1mb" ofType:@"dat"];
    if (filePath == nil) {
      // Use bundleForClass to allow 1mb.dat to be in the test target's bundle.
      NSBundle *bundle = [NSBundle bundleForClass:[self class]];
      filePath = [bundle pathForResource:@"1mb" ofType:@"dat"];
    }
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    XCTAssertNotNil(data, "Could not load bundled file");

    for (NSString *largeFile in largeFiles) {
      FIRStorageReference *file = [[FIRStorage storage].reference child:largeFile];
      [file putData:data
            metadata:nil
          completion:^(FIRStorageMetadata *metadata, NSError *error) {
            XCTAssertNil(error);
            [setUpExpectation fulfill];
          }];
    }

    for (NSString *emptyFile in emptyFiles) {
      FIRStorageReference *file = [[FIRStorage storage].reference child:emptyFile];
      [file putData:[NSData data]
            metadata:nil
          completion:^(FIRStorageMetadata *metadata, NSError *error) {
            XCTAssertNil(error);
            [setUpExpectation fulfill];
          }];
    }

    [self waitForExpectations];
  });
}

- (void)tearDown {
  self.app = nil;
  self.storage = nil;

  [super tearDown];
}

- (void)testName {
  NSString *aGSURI = [NSString
      stringWithFormat:@"gs://%@.appspot.com/path/to", [[FIRApp defaultApp] options].projectID];
  FIRStorageReference *ref = [self.storage referenceForURL:aGSURI];
  XCTAssertEqualObjects(ref.description, aGSURI);
}

- (void)testGetMetadata {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testGetMetadata"];
  FIRStorageReference *ref = [self.storage.reference child:@"ios/public/1mb"];

  [ref metadataWithCompletion:^(FIRStorageMetadata *metadata, NSError *error) {
    XCTAssertNotNil(metadata, "Metadata should not be nil");
    XCTAssertNil(error, "Error should be nil");
    [expectation fulfill];
  }];

  [self waitForExpectations];
}

- (void)testDelete {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testDelete"];

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

- (void)testPutDataSpecialCharacter {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPutDataSpecialCharacter"];
  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/-._~!$'()*,=:@&+;"];

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

- (void)testPutDataInBackgroundQueue {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testPutDataInBackgroundQueue"];
  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/testBytesUpload"];

  NSData *data = [@"Hello World" dataUsingEncoding:NSUTF8StringEncoding];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [ref putData:data
          metadata:nil
        completion:^(FIRStorageMetadata *metadata, NSError *error) {
          XCTAssertNotNil(metadata, "Metadata should not be nil");
          XCTAssertNil(error, "Error should be nil");
          [expectation fulfill];
        }];
  });

  [self waitForExpectations];
}

- (void)testPutDataWithEmptyData {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPutDataWithEmptyData"];

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

- (void)testPutData {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPutData"];
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

- (void)testPutFile {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPutFile"];

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
                uploadedBytes = (long)progress.completedUnitCount;
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

- (void)testPutDataNoMetadata {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPutDataNoMetadata"];

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

- (void)testPutFileNoMetadata {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPutFileNoMetadata"];

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

- (void)testGetData {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testGetData"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

  [ref dataWithMaxSize:1 * 1024 * 1024
            completion:^(NSData *data, NSError *error) {
              XCTAssertNotNil(data, "Data should not be nil");
              XCTAssertNil(error, "Error should be nil");
              [expectation fulfill];
            }];

  [self waitForExpectations];
}

- (void)testGetDataInBackgroundQueue {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testGetDataInBackgroundQueue"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [ref dataWithMaxSize:1 * 1024 * 1024
              completion:^(NSData *data, NSError *error) {
                XCTAssertNotNil(data, "Data should not be nil");
                XCTAssertNil(error, "Error should be nil");
                [expectation fulfill];
              }];
  });

  [self waitForExpectations];
}

- (void)testGetDataWithCustomCallbackQueue {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testUnauthenticatedGetDataInCustomCallbackQueue"];

  NSString *callbackQueueLabelString = @"customCallbackQueue";
  const char *callbackQueueLabel = [callbackQueueLabelString UTF8String];
  const void *callbackQueueKey = callbackQueueLabel;
  dispatch_queue_t callbackQueue = dispatch_queue_create(callbackQueueLabel, NULL);

  dispatch_queue_set_specific(callbackQueue, callbackQueueKey, (void *)callbackQueueKey, NULL);
  _storage.callbackQueue = callbackQueue;

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];
  [ref dataWithMaxSize:1 * 1024 * 1024
            completion:^(NSData *data, NSError *error) {
              XCTAssertNotNil(data, "Data should not be nil");
              XCTAssertNil(error, "Error should be nil");

              char *currentQueueLabel = dispatch_get_specific(callbackQueueKey);
              NSString *currentQueueLabelString = [NSString stringWithUTF8String:currentQueueLabel];
              XCTAssertEqualObjects(currentQueueLabelString, callbackQueueLabelString);

              [expectation fulfill];

              // Reset the callbackQueue to default (main queue).
              self.storage.callbackQueue = dispatch_get_main_queue();
              dispatch_queue_set_specific(callbackQueue, callbackQueueKey, NULL, NULL);
            }];

  [self waitForExpectations];
}

- (void)testGetDataTooSmall {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testGetDataTooSmall"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

  /// Only allow 1kB size, which is smaller than our file
  [ref dataWithMaxSize:1 * 1024
            completion:^(NSData *data, NSError *error) {
              XCTAssertNil(data);
              XCTAssertEqual(error.code, FIRStorageErrorCodeDownloadSizeExceeded);
              [expectation fulfill];
            }];

  [self waitForExpectations];
}

- (void)testGetDownloadURL {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testGetDownloadURL"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

  // Download URL format is
  // "https://firebasestorage.googleapis.com/v0/b/{bucket}/o/{path}?alt=media&token={token}"
  NSString *downloadURLPattern =
      @"^https:\\/\\/firebasestorage.googleapis.com\\/v0\\/b\\/[^\\/]*\\/o\\/"
      @"ios%2Fpublic%2F1mb\\?alt=media&token=[a-z0-9-]*$";

  [ref downloadURLWithCompletion:^(NSURL *downloadURL, NSError *error) {
    XCTAssertNil(error);
    NSRegularExpression *testRegex =
        [NSRegularExpression regularExpressionWithPattern:downloadURLPattern options:0 error:nil];
    NSString *urlString = [downloadURL absoluteString];
    XCTAssertEqual([testRegex numberOfMatchesInString:urlString
                                              options:0
                                                range:NSMakeRange(0, [urlString length])],
                   1);
    [expectation fulfill];
  }];

  [self waitForExpectations];
}

- (void)testGetFile {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testGetFile"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/helloworld"];

  NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
  NSURL *fileURL =
      [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"txt"];

  [ref putData:[@"Hello World" dataUsingEncoding:NSUTF8StringEncoding]
        metadata:nil
      completion:^(FIRStorageMetadata *metadata, NSError *error) {
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
                    }];
      }];

  [self waitForExpectations];
}

- (void)testCancelDownload {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testCancelDownload"];

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

- (void)assertMetadata:(FIRStorageMetadata *)actualMetadata
           contentType:(NSString *)expectedContentType
        customMetadata:(NSDictionary *)expectedCustomMetadata {
  XCTAssertEqualObjects(actualMetadata.cacheControl, @"cache-control");
  XCTAssertEqualObjects(actualMetadata.contentDisposition, @"content-disposition");
  XCTAssertEqualObjects(actualMetadata.contentEncoding, @"gzip");
  XCTAssertEqualObjects(actualMetadata.contentLanguage, @"de");
  XCTAssertEqualObjects(actualMetadata.contentType, expectedContentType);
  XCTAssertTrue([actualMetadata.md5Hash length] == 24);
  for (NSString *key in expectedCustomMetadata) {
    XCTAssertEqualObjects([actualMetadata.customMetadata objectForKey:key],
                          [expectedCustomMetadata objectForKey:key]);
  }
}

- (void)assertMetadataNil:(FIRStorageMetadata *)actualMetadata {
  XCTAssertNil(actualMetadata.cacheControl);
  XCTAssertNil(actualMetadata.contentDisposition);
  XCTAssertEqualObjects(actualMetadata.contentEncoding, @"identity");
  XCTAssertNil(actualMetadata.contentLanguage);
  XCTAssertNil(actualMetadata.contentType);
  XCTAssertTrue([actualMetadata.md5Hash length] == 24);
  XCTAssertNil(actualMetadata.customMetadata);
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

  [ref updateMetadata:metadata
           completion:^(FIRStorageMetadata *updatedMetadata, NSError *error) {
             XCTAssertNil(error);
             [self assertMetadata:updatedMetadata
                      contentType:@"content-type-a"
                   customMetadata:@{@"a" : @"b"}];

             // Update a subset of the metadata using the existing object.
             FIRStorageMetadata *metadata = updatedMetadata;
             metadata.contentType = @"content-type-b";
             metadata.customMetadata = @{@"a" : @"b", @"c" : @"d"};

             [ref updateMetadata:metadata
                      completion:^(FIRStorageMetadata *updatedMetadata, NSError *error) {
                        XCTAssertNil(error);
                        [self assertMetadata:updatedMetadata
                                 contentType:@"content-type-b"
                              customMetadata:@{@"a" : @"b", @"c" : @"d"}];

                        // Clear all metadata.
                        FIRStorageMetadata *metadata = updatedMetadata;
                        metadata.cacheControl = nil;
                        metadata.contentDisposition = nil;
                        metadata.contentEncoding = nil;
                        metadata.contentLanguage = nil;
                        metadata.contentType = nil;
                        metadata.customMetadata = [NSDictionary dictionary];

                        [ref updateMetadata:metadata
                                 completion:^(FIRStorageMetadata *updatedMetadata, NSError *error) {
                                   XCTAssertNil(error);
                                   [self assertMetadataNil:updatedMetadata];
                                   [expectation fulfill];
                                 }];
                      }];
           }];

  [self waitForExpectations];
}

- (void)testResumeGetFile {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testResumeGetFile"];

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
                downloadedBytes = (long)progress.completedUnitCount;
                if (progress.completedUnitCount > resumeAtBytes) {
                  // Making sure the main run loop is busy.
                  for (int i = 0; i < 500; ++i) {
                    dispatch_async(dispatch_get_main_queue(), ^{
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

- (void)testResumeGetFileInBackgroundQueue {
  XCTestExpectation *expectation =
      [self expectationWithDescription:@"testResumeGetFileInBackgroundQueue"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/1mb"];

  NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
  NSURL *fileURL =
      [[tmpDirURL URLByAppendingPathComponent:@"hello"] URLByAppendingPathExtension:@"txt"];

  __block long resumeAtBytes = 256 * 1024;
  __block long downloadedBytes = 0;

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
                downloadedBytes = (long)progress.completedUnitCount;
                if (progress.completedUnitCount > resumeAtBytes) {
                  NSLog(@"Pausing");
                  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [task pause];
                  });
                  resumeAtBytes = INT_MAX;
                }
              }];

  [task observeStatus:FIRStorageTaskStatusPause
              handler:^(FIRStorageTaskSnapshot *snapshot) {
                XCTAssertEqualObjects([snapshot description], @"<State: Paused>");
                NSLog(@"Resuming");
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                  [task resume];
                });
              }];

  [self waitForExpectations];
  XCTAssertEqual(INT_MAX, resumeAtBytes);
}

- (void)testPagedListFiles {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testPagedListFiles"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/list"];

  [ref listWithMaxResults:2
               completion:^(FIRStorageListResult *_Nullable listResult, NSError *_Nullable error) {
                 XCTAssertNotNil(listResult);
                 XCTAssertNil(error);

                 XCTAssertEqualObjects(listResult.items, (@[ [ref child:@"a"], [ref child:@"b"] ]));
                 XCTAssertEqualObjects(listResult.prefixes, @[]);
                 XCTAssertNotNil(listResult.pageToken);

                 [ref listWithMaxResults:2
                               pageToken:listResult.pageToken
                              completion:^(FIRStorageListResult *_Nullable listResult,
                                           NSError *_Nullable error) {
                                XCTAssertNotNil(listResult);
                                XCTAssertNil(error);

                                XCTAssertEqualObjects(listResult.items, @[]);
                                XCTAssertEqualObjects(listResult.prefixes,
                                                      @[ [ref child:@"prefix"] ]);
                                XCTAssertNil(listResult.pageToken);

                                [expectation fulfill];
                              }];
               }];

  [self waitForExpectations];
}

- (void)testListAllFiles {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testListAllFiles"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@"ios/public/list"];

  [ref listAllWithCompletion:^(FIRStorageListResult *_Nullable listResult,
                               NSError *_Nullable error) {
    XCTAssertNotNil(listResult);
    XCTAssertNil(error);

    XCTAssertEqualObjects(listResult.items, (@[ [ref child:@"a"], [ref child:@"b"] ]));
    XCTAssertEqualObjects(listResult.prefixes, @[ [ref child:@"prefix"] ]);
    XCTAssertNil(listResult.pageToken);

    [expectation fulfill];
  }];

  [self waitForExpectations];
}

- (void)testListFilesAtRoot {
  XCTestExpectation *expectation = [self expectationWithDescription:@"testListFilesAtRoot"];

  FIRStorageReference *ref = [self.storage referenceWithPath:@""];

  [ref listAllWithCompletion:^(FIRStorageListResult *_Nullable listResult,
                               NSError *_Nullable error) {
    XCTAssertNotNil(listResult);
    XCTAssertNil(error);
    XCTAssertNil(listResult.pageToken);
    [expectation fulfill];
  }];

  [self waitForExpectations];
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
