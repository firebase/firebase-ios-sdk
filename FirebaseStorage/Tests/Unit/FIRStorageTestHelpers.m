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

#import "FirebaseStorage/Tests/Unit/FIRStorageTestHelpers.h"

#import "FirebaseStorage/Sources/FIRStorageComponent.h"
#import "SharedTestUtilities/FIRComponentTestUtilities.h"

NSString *const kGoogleHTTPErrorDomain = @"com.google.HTTPStatus";
NSString *const kHTTPVersion = @"HTTP/1.1";
NSString *const kUnauthenticatedResponseString =
    @"<html><body><p>User not authenticated. Authentication via Authorization header required. "
    @"Authorization Header does not match expected format of 'Authorization: Firebase "
    @"<JWT>'.</p></body></html>";
NSString *const kUnauthorizedResponseString =
    @"<html><body><p>User not authorized. Authentication via Authorization header required. "
    @"Authorization Header does not match expected format of 'Authorization: Firebase "
    @"<JWT>'.</p></body></html>";
NSString *const kNotFoundResponseString = @"<html><body><p>Object not found.</p></body></html>";
NSString *const kInvalidJSONResponseString = @"This is not a JSON object";
NSString *const kFIRStorageObjectURL =
    @"https://firebasestorage.googleapis.com/v0/b/bucket/o/object";
NSString *const kFIRStorageBucketURL = @"https://firebasestorage.googleapis.com/v0/b/bucket/o";
NSString *const kFIRStorageNotFoundURL =
    @"https://firebasestorage.googleapis.com/v0/b/bucket/o/i/dont/exist";
NSString *const kFIRStorageTestAuthToken = @"1234-5678-9012-3456-7890";
NSString *const kFIRStorageAppName = @"app";

@implementation FIRStorageTestHelpers

+ (FIRApp *)mockedApp {
  // In order to properly instantiate a FIRStorage instance with `storageForApp:`, it needs to have
  // the FIRStorageComponent registered. Create a class mock, and override the container with the
  // correct contents.
  id app = OCMClassMock([FIRApp class]);
  NSMutableSet<Class> *registrants = [NSMutableSet setWithObject:[FIRStorageComponent class]];
  FIRComponentContainer *container = [[FIRComponentContainer alloc] initWithApp:app
                                                                    registrants:registrants];
  OCMStub([app container]).andReturn(container);
  return app;
}

+ (NSURL *)objectURL {
  return [NSURL URLWithString:kFIRStorageObjectURL];
}

+ (NSURL *)bucketURL {
  return [NSURL URLWithString:kFIRStorageBucketURL];
}

+ (NSURL *)notFoundURL {
  return [NSURL URLWithString:kFIRStorageNotFoundURL];
}

+ (FIRStoragePath *)objectPath {
  return [FIRStoragePath pathFromString:kFIRStorageObjectURL];
}

+ (FIRStoragePath *)bucketPath {
  return [FIRStoragePath pathFromString:kFIRStorageBucketURL];
}

+ (FIRStoragePath *)notFoundPath {
  return [FIRStoragePath pathFromString:kFIRStorageNotFoundURL];
}

+ (GTMSessionFetcherTestBlock)successBlock {
  return [FIRStorageTestHelpers successBlockWithMetadata:nil];
}

+ (GTMSessionFetcherTestBlock)successBlockWithMetadata:(nullable FIRStorageMetadata *)metadata {
  NSData *data;
  if (metadata) {
    data = [NSData frs_dataFromJSONDictionary:[metadata dictionaryRepresentation]];
  }
  return [FIRStorageTestHelpers blockForData:data statusCode:200];
}

+ (GTMSessionFetcherTestBlock)unauthenticatedBlock {
  NSData *data = [kUnauthenticatedResponseString dataUsingEncoding:NSUTF8StringEncoding];
  return [FIRStorageTestHelpers blockForData:data statusCode:401];
}

+ (GTMSessionFetcherTestBlock)unauthorizedBlock {
  NSData *data = [kUnauthorizedResponseString dataUsingEncoding:NSUTF8StringEncoding];
  return [FIRStorageTestHelpers blockForData:data statusCode:403];
}

+ (GTMSessionFetcherTestBlock)notFoundBlock {
  NSData *data = [kNotFoundResponseString dataUsingEncoding:NSUTF8StringEncoding];
  return [FIRStorageTestHelpers blockForData:data statusCode:404];
}

+ (GTMSessionFetcherTestBlock)invalidJSONBlock {
  NSData *data = [kInvalidJSONResponseString dataUsingEncoding:NSUTF8StringEncoding];
  return [FIRStorageTestHelpers blockForData:data statusCode:200];
}

#pragma mark - Private methods

+ (GTMSessionFetcherTestBlock)blockForData:(nullable NSData *)data statusCode:(NSInteger)code {
  GTMSessionFetcherTestBlock block =
      ^(GTMSessionFetcher *fetcher, GTMSessionFetcherTestResponse response) {
        NSHTTPURLResponse *httpResponse = [[NSHTTPURLResponse alloc] initWithURL:fetcher.request.URL
                                                                      statusCode:code
                                                                     HTTPVersion:kHTTPVersion
                                                                    headerFields:nil];
        NSError *error;
        if (code >= 400) {
          NSDictionary *userInfo;
          if (data) {
            userInfo = @{@"data" : data};
          }
          error = [NSError errorWithDomain:kGoogleHTTPErrorDomain code:code userInfo:userInfo];
        }

        response(httpResponse, data, error);
      };
  return block;
}

+ (void)waitForExpectation:(id)test {
  [test waitForExpectationsWithTimeout:kExpectationTimeoutSeconds
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   NSLog(@"Error: %@", error);
                                 }
                               }];
}

@end
