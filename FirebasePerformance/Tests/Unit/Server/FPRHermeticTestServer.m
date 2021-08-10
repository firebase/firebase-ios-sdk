// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Tests/Unit/Server/FPRHermeticTestServer.h"
#import "FirebasePerformance/Tests/Unit/FPRTestUtils.h"

@interface FPRHermeticTestServer ()

/** The server object. */
@property(nonatomic) GCDWebServer *server;

// Redeclare as readwrite and mutable.
@property(nonatomic, readwrite) NSMutableDictionary<NSString *, NSURL *> *registeredTestPaths;

@end

@implementation FPRHermeticTestServer

- (instancetype)init {
  self = [super init];
  if (self) {
    [GCDWebServer setLogLevel:3];
    _server = [[GCDWebServer alloc] init];
    _registeredTestPaths = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc {
  [_server stop];
}

- (void)registerTestPaths {
  [self registerPathIndex];
  [self registerPathTest];
  [self registerPathTestRedirect];
  [self registerPathTestDownload];
  [self registerPathTestBigDownload];
  [self registerPathTestUpload];
}

- (void)start {
  NSAssert(self.server.isRunning == NO, @"The server should not be already running.");
  NSError *error;
  [self.server
      startWithOptions:@{GCDWebServerOption_Port : @0, GCDWebServerOption_BindToLocalhost : @YES}
                 error:&error];
  NSAssert(error == nil, @"Error when starting server: %@", error);
}

- (void)stop {
  NSAssert(self.server.isRunning, @"The server should be running before stopping.");
  [self.server stop];
}

- (BOOL)isRunning {
  return [self.server isRunning];
}

- (NSURL *)serverURL {
  return _server.serverURL;
}

#pragma mark - HTTP Path handling methods

/** Registers the index path, "/". */
- (void)registerPathIndex {
  id processBlock = ^GCDWebServerResponse *(GCDWebServerRequest *request) {
    GCDWebServerDataResponse *response = [[GCDWebServerDataResponse alloc] initWithHTML:@"Hello!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self->_responseCompletedBlock) {
                       self->_responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"GET"
                              path:@"/"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

/** Registers the "/test" path, which responds with plain HTML. */
- (void)registerPathTest {
  id processBlock = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    GCDWebServerDataResponse *response = [[GCDWebServerDataResponse alloc] initWithHTML:@"Hello2!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self->_responseCompletedBlock) {
                       self->_responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"GET"
                              path:@"/test"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

/** Registers the "/testRedirect" path, which sends a redirect response. */
- (void)registerPathTestRedirect {
  id processBlock = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    NSURL *redirectURL = [NSURL URLWithString:@"/test"];
    GCDWebServerDataResponse *response =
        [[GCDWebServerDataResponse alloc] initWithRedirect:redirectURL permanent:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self->_responseCompletedBlock) {
                       self->_responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"GET"
                              path:@"/testRedirect"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

/** Registers the "/testDownload" path, which responds with a small amount of data. */
- (void)registerPathTestDownload {
  NSBundle *bundle = [FPRTestUtils getBundle];
  NSString *filePath = [bundle pathForResource:@"smallDownloadFile" ofType:@""];
  id processBlock = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    GCDWebServerFileResponse *response = [[GCDWebServerFileResponse alloc] initWithFile:filePath];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self->_responseCompletedBlock) {
                       self->_responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"GET"
                              path:@"/testDownload"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

/** Registers the "/testBigDownload" path, which responds with a larger amount of data. */
- (void)registerPathTestBigDownload {
  NSBundle *bundle = [FPRTestUtils getBundle];
  NSString *filePath = [bundle pathForResource:@"bigDownloadFile" ofType:@""];
  id processBlock = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    GCDWebServerFileResponse *response = [[GCDWebServerFileResponse alloc] initWithFile:filePath];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self->_responseCompletedBlock) {
                       self->_responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"GET"
                              path:@"/testBigDownload"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

/** Registers the "/testUpload" path, which accepts some data. */
- (void)registerPathTestUpload {
  id processBlock = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    GCDWebServerResponse *response = [[GCDWebServerDataResponse alloc] initWithHTML:@"ok"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self->_responseCompletedBlock) {
                       self->_responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"POST"
                              path:@"/testUpload"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

@end
