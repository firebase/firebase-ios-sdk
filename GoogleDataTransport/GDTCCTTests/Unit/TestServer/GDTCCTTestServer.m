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

#import "GoogleDataTransport/GDTCCTTests/Unit/TestServer/GDTCCTTestServer.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORAssert.h"

#import <nanopb/pb_decode.h>
#import <nanopb/pb_encode.h>

#import "GoogleDataTransport/GDTCCTLibrary/Private/GDTCCTNanopbHelpers.h"

#import "GoogleDataTransport/GDTCCTLibrary/Protogen/nanopb/cct.nanopb.h"

@interface GDTCCTTestServer ()

/** The server object. */
@property(nonatomic) GCDWebServer *server;

// Redeclare as readwrite and mutable.
@property(nonatomic, readwrite) NSMutableDictionary<NSString *, NSURL *> *registeredTestPaths;

@end

@implementation GDTCCTTestServer

- (instancetype)init {
  self = [super init];
  if (self) {
    [GCDWebServer setLogLevel:3];
    _server = [[GCDWebServer alloc] init];
    _registeredTestPaths = [[NSMutableDictionary alloc] init];
    _responseNextRequestWaitTime = 42.42;
  }
  return self;
}

- (void)dealloc {
  [_server stop];
}

- (void)start {
  GDTCORAssert(self.server.isRunning == NO, @"The server should not be already running.");
  NSError *error;
  [self.server
      startWithOptions:@{GCDWebServerOption_Port : @0, GCDWebServerOption_BindToLocalhost : @YES}
                 error:&error];
  GDTCORAssert(error == nil, @"Error when starting server: %@", error);
}

- (void)stop {
  GDTCORAssert(self.server.isRunning, @"The server should be running before stopping.");
  [self.server stop];
}

- (BOOL)isRunning {
  return [self.server isRunning];
}

- (NSURL *)serverURL {
  return _server.serverURL;
}

#pragma mark - Private helper methods

/** Constructs a nanopb LogResponse object, serializes it to NSData, and returns it.
 *
 * @return NSData respresenting a LogResponse with a next_request_wait_millis of 42424 milliseconds.
 */
- (NSData *)responseData {
  gdt_cct_LogResponse logResponse = gdt_cct_LogResponse_init_default;
  logResponse.next_request_wait_millis = self.responseNextRequestWaitTime * 1000;
  logResponse.has_next_request_wait_millis = 1;

  pb_ostream_t sizestream = PB_OSTREAM_SIZING;
  // Encode 1 time to determine the size.
  if (!pb_encode(&sizestream, gdt_cct_LogResponse_fields, &logResponse)) {
    GDTCORAssert(NO, @"Error in nanopb encoding for size: %s", PB_GET_ERROR(&sizestream));
  }

  // Encode a 2nd time to actually get the bytes from it.
  size_t bufferSize = sizestream.bytes_written;
  CFMutableDataRef dataRef = CFDataCreateMutable(CFAllocatorGetDefault(), bufferSize);
  CFDataSetLength(dataRef, bufferSize);
  pb_ostream_t ostream = pb_ostream_from_buffer((void *)CFDataGetBytePtr(dataRef), bufferSize);
  if (!pb_encode(&ostream, gdt_cct_LogResponse_fields, &logResponse)) {
    GDTCORAssert(NO, @"Error in nanopb encoding for bytes: %s", PB_GET_ERROR(&ostream));
  }
  pb_release(gdt_cct_LogResponse_fields, &logResponse);
  return CFBridgingRelease(dataRef);
}

#pragma mark - HTTP Path handling methods

- (void)registerLogBatchPath {
  __auto_type __weak weakSelf = self;
  [self.server addHandlerForMethod:@"POST"
                              path:@"/logBatch"
                      requestClass:[GCDWebServerRequest class]
                 asyncProcessBlock:^(__kindof GCDWebServerRequest *_Nonnull request,
                                     GCDWebServerCompletionBlock _Nonnull completionBlock) {
                   if (!weakSelf) {
                     return;
                   }
                   __auto_type self = weakSelf;

                   GCDWebServerDataResponse *response =
                       [[GCDWebServerDataResponse alloc] initWithData:[self responseData]
                                                          contentType:@"application/text"];
                   response.gzipContentEncodingEnabled = YES;

                   GCDWebServerCompletionBlock completionWithHook =
                       ^(GCDWebServerResponse *_Nullable response) {
                         if (self.responseCompletedBlock) {
                           self.responseCompletedBlock(request, response);
                         }
                         completionBlock(response);
                       };

                   if (self.requestHandler) {
                     self.requestHandler(request, response, completionWithHook);
                   } else {
                     completionWithHook(response);
                   }
                 }];
}

- (void)registerRedirectPaths {
  id processBlock301 = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    NSURL *redirectURL = [self->_server.serverURL URLByAppendingPathComponent:@"logBatch"];
    GCDWebServerResponse *response = [GCDWebServerResponse responseWithRedirect:redirectURL
                                                                      permanent:NO];
    response.statusCode = 301;
    response.gzipContentEncodingEnabled = YES;
    return response;
  };
  [self.server addHandlerForMethod:@"POST"
                              path:@"/logRedirect301"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock301];

  id processBlock302 = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    NSURL *redirectURL = [self->_server.serverURL URLByAppendingPathComponent:@"logBatch"];
    GCDWebServerResponse *response = [GCDWebServerResponse responseWithRedirect:redirectURL
                                                                      permanent:NO];
    response.statusCode = 302;
    response.gzipContentEncodingEnabled = YES;
    return response;
  };
  [self.server addHandlerForMethod:@"POST"
                              path:@"/logRedirect302"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock302];

  id processBlock307 = ^GCDWebServerResponse *(__kindof GCDWebServerRequest *request) {
    NSURL *redirectURL = [self->_server.serverURL URLByAppendingPathComponent:@"logBatch"];
    GCDWebServerResponse *response = [GCDWebServerResponse responseWithRedirect:redirectURL
                                                                      permanent:NO];
    response.statusCode = 307;
    response.gzipContentEncodingEnabled = YES;
    return response;
  };
  [self.server addHandlerForMethod:@"POST"
                              path:@"/logRedirect307"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:processBlock307];
}

@end
