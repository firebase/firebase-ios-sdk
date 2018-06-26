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

#import "FIRNetwork.h"
#import <GoogleUtilities/GULNetwork.h>

@interface FIRNetwork ()
@end

@implementation FIRNetwork {
  // Wrap GULNetwork until FIRNetwork can be eliminated in dependencies
  GULNetwork *_gulNetwork;
}

- (instancetype)init {
  return [self initWithReachabilityHost:kGULNetworkReachabilityHost];
}

- (instancetype)initWithReachabilityHost:(NSString *)reachabilityHost {
  self = [super init];
  if (self) {
    _gulNetwork = [[GULNetwork alloc] initWithReachabilityHost:reachabilityHost];
  }
  return self;
}

//- (void)dealloc {
//  _reachability.reachabilityDelegate = nil;
//  [_reachability stop];
//}

#pragma mark - External Methods

+ (void)handleEventsForBackgroundURLSessionID:(NSString *)sessionID
                            completionHandler:(GULNetworkSystemCompletionHandler)completionHandler {
  [GULNetworkURLSession handleEventsForBackgroundURLSessionID:sessionID
                                            completionHandler:completionHandler];
}

- (NSString *)postURL:(NSURL *)url
                   payload:(NSData *)payload
                     queue:(dispatch_queue_t)queue
    usingBackgroundSession:(BOOL)usingBackgroundSession
         completionHandler:(FIRNetworkCompletionHandler)handler {
  return [_gulNetwork postURL:url payload:payload queue:queue usingBackgroundSession:usingBackgroundSession completionHandler handler];
}

- (NSString *)getURL:(NSURL *)url
                   headers:(NSDictionary *)headers
                     queue:(dispatch_queue_t)queue
    usingBackgroundSession:(BOOL)usingBackgroundSession
         completionHandler:(FIRNetworkCompletionHandler)handler {
  return [_gulNetwork getURL:url headers:headers queue:queue usingBackgroundSession:usingBackgroundSession completionHandler:handler];
}

- (BOOL)hasUploadInProgress {
  return [_gulNetwork hasUploadInProgress];
}

#pragma mark - Network Reachability

/// Tells reachability delegate to call reachabilityDidChangeToStatus: to notify the network
/// reachability has changed.
- (void)reachability:(FIRReachabilityChecker *)reachability
       statusChanged:(FIRReachabilityStatus)status {
  [_gulNetwork reachability:reachability statusChanged:status];
}

#pragma mark - Network logger delegate

- (void)setLoggerDelegate:(id<FIRNetworkLoggerDelegate>)loggerDelegate {
  // Explicitly check whether the delegate responds to the methods because conformsToProtocol does
  // not work correctly even though the delegate does respond to the methods.
  [_gulNetwork setLoggerDelegate:(id<GULNetworkLoggerDelegate>)loggerDelegate];
}

#pragma mark - Private methods

/// Handles network error and calls completion handler with the error.
- (void)handleErrorWithCode:(NSInteger)code
                      queue:(dispatch_queue_t)queue
                withHandler:(FIRNetworkCompletionHandler)handler {
  [_gulNetwork handleErrorWithCode:code queue:queue withHandler:handler];
}

#pragma mark - Network logger

- (void)FIRNetwork_logWithLevel:(FIRNetworkLogLevel)logLevel
                    messageCode:(FIRNetworkMessageCode)messageCode
                        message:(NSString *)message
                       contexts:(NSArray *)contexts {
  [_gulNetwork GULNetworkLogLevel:logLevel messageCode:messageCode message:message contexts:contexts];
}

- (void)FIRNetwork_logWithLevel:(FIRNetworkLogLevel)logLevel
                    messageCode:(FIRNetworkMessageCode)messageCode
                        message:(NSString *)message
                        context:(id)context {
  [_gulNetwork GULNetworkLogLevel:logLevel messageCode:messageCode message:message context:context];
}

- (void)FIRNetwork_logWithLevel:(FIRNetworkLogLevel)logLevel
                    messageCode:(FIRNetworkMessageCode)messageCode
                        message:(NSString *)message {
  [_gulNetwork GULNetworkLogLevel:logLevel messageCode:messageCode message:message];
}

@end
