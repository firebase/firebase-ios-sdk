/*
 * Copyright 2019 Google
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

#import "GoogleDataTransport/GDTCORTests/Integration/TestServer/GDTCORTestServer.h"

@interface GDTCORTestServer ()

/** The server object. */
@property(nonatomic) GCDWebServer *server;

// Redeclare as readwrite and mutable.
@property(nonatomic, readwrite) NSMutableDictionary<NSString *, NSURL *> *registeredTestPaths;

@end

@implementation GDTCORTestServer

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
  [self registerLogPath];
  [self registerLogBatchPath];
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

/** Registers the /log path, which responds with some JSON. */
- (void)registerLogPath {
  id processBlock = ^GCDWebServerResponse *(GCDWebServerRequest *request) {
    GCDWebServerDataResponse *response = [[GCDWebServerDataResponse alloc] initWithHTML:@"Hello!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self.responseCompletedBlock) {
                       self.responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"POST"
                              path:@"/log"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

/** Registers the /logBatch path, which responds with some JSON. */
- (void)registerLogBatchPath {
  id processBlock = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    GCDWebServerDataResponse *response = [[GCDWebServerDataResponse alloc] initWithHTML:@"Hello2!"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                     if (self.responseCompletedBlock) {
                       self.responseCompletedBlock(request, response);
                     }
                   });
    return response;
  };
  [self.server addHandlerForMethod:@"POST"
                              path:@"/logBatch"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock];
}

@end
