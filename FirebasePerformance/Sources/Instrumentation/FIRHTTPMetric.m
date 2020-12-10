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

#import "FirebasePerformance/Sources/Public/FIRHTTPMetric.h"
#import "FirebasePerformance/Sources/Instrumentation/FIRHTTPMetric+Private.h"

#import "FirebasePerformance/Sources/Common/FPRConstants.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/FPRConsoleLogger.h"
#import "FirebasePerformance/Sources/FPRDataUtils.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRNetworkTrace.h"

@interface FIRHTTPMetric ()

/* A placeholder URLRequest used for SDK metric tracking. */
@property(nonatomic, strong) NSURLRequest *URLRequest;

@end

@implementation FIRHTTPMetric

- (nullable instancetype)initWithURL:(nonnull NSURL *)URL HTTPMethod:(FIRHTTPMethod)httpMethod {
  BOOL tracingEnabled = [FPRConfigurations sharedInstance].isDataCollectionEnabled;
  if (!tracingEnabled) {
    FPRLogInfo(kFPRTraceDisabled, @"Trace feature is disabled. Dropping http metric - %@",
               URL.absoluteString);
    return nil;
  }

  BOOL sdkEnabled = [[FPRConfigurations sharedInstance] sdkEnabled];
  if (!sdkEnabled) {
    FPRLogInfo(kFPRTraceDisabled, @"Dropping event since Performance SDK is disabled.");
    return nil;
  }

  NSMutableURLRequest *URLRequest = [[NSMutableURLRequest alloc] initWithURL:URL];
  NSString *HTTPMethodString = nil;
  switch (httpMethod) {
    case FIRHTTPMethodGET:
      HTTPMethodString = @"GET";
      break;

    case FIRHTTPMethodPUT:
      HTTPMethodString = @"PUT";
      break;

    case FIRHTTPMethodPOST:
      HTTPMethodString = @"POST";
      break;

    case FIRHTTPMethodHEAD:
      HTTPMethodString = @"HEAD";
      break;

    case FIRHTTPMethodDELETE:
      HTTPMethodString = @"DELETE";
      break;

    case FIRHTTPMethodPATCH:
      HTTPMethodString = @"PATCH";
      break;

    case FIRHTTPMethodOPTIONS:
      HTTPMethodString = @"OPTIONS";
      break;

    case FIRHTTPMethodTRACE:
      HTTPMethodString = @"TRACE";
      break;

    case FIRHTTPMethodCONNECT:
      HTTPMethodString = @"CONNECT";
      break;
  }
  [URLRequest setHTTPMethod:HTTPMethodString];

  if (URLRequest && HTTPMethodString != nil) {
    self = [super init];
    _networkTrace = [[FPRNetworkTrace alloc] initWithURLRequest:URLRequest];
    _URLRequest = [URLRequest copy];
    return self;
  }

  FPRLogError(kFPRInstrumentationInvalidInputs, @"Invalid URL");
  return nil;
}

- (void)start {
  [self.networkTrace start];
}

- (void)markRequestComplete {
  [self.networkTrace checkpointState:FPRNetworkTraceCheckpointStateRequestCompleted];
}

- (void)markResponseStart {
  [self.networkTrace checkpointState:FPRNetworkTraceCheckpointStateResponseReceived];
}

- (void)stop {
  self.networkTrace.requestSize = self.requestPayloadSize;
  self.networkTrace.responseSize = self.responsePayloadSize;
  // Create a dummy URL Response that will be used for data extraction.
  NSString *responsePayloadSize =
      [[NSString alloc] initWithFormat:@"%ld", self.responsePayloadSize];
  NSMutableDictionary<NSString *, NSString *> *headerFields =
      [[NSMutableDictionary<NSString *, NSString *> alloc] init];
  if (self.responseContentType) {
    [headerFields setObject:self.responseContentType forKey:@"Content-Type"];
  }
  [headerFields setObject:responsePayloadSize forKey:@"Content-Length"];

  if (self.responseCode == 0) {
    FPRLogError(kFPRInstrumentationInvalidInputs, @"Response code not set for request - %@",
                self.URLRequest.URL);
    return;
  }
  NSHTTPURLResponse *URLResponse = [[NSHTTPURLResponse alloc] initWithURL:self.URLRequest.URL
                                                               statusCode:self.responseCode
                                                              HTTPVersion:nil
                                                             headerFields:headerFields];

  [self.networkTrace didCompleteRequestWithResponse:URLResponse error:nil];
}

#pragma mark - Custom attributes related methods

- (NSDictionary<NSString *, NSString *> *)attributes {
  return [self.networkTrace attributes];
}

- (void)setValue:(NSString *)value forAttribute:(nonnull NSString *)attribute {
  [self.networkTrace setValue:value forAttribute:attribute];
}

- (NSString *)valueForAttribute:(NSString *)attribute {
  return [self.networkTrace valueForAttribute:attribute];
}

- (void)removeAttribute:(NSString *)attribute {
  [self.networkTrace removeAttribute:attribute];
}

@end
