/*
 * Copyright 2017 Google
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

#import "Firebase/Messaging/FIRMessagingClient.h"

#import <FirebaseInstanceID/FIRInstanceID_Private.h>
#import <FirebaseMessaging/FIRMessaging.h>

#import "Firebase/Messaging/FIRMessagingConstants.h"
#import "Firebase/Messaging/FIRMessagingDefines.h"
#import "Firebase/Messaging/FIRMessagingLogger.h"
#import "Firebase/Messaging/FIRMessagingPubSubRegistrar.h"
#import "Firebase/Messaging/FIRMessagingTopicsCommon.h"
#import "Firebase/Messaging/FIRMessagingUtilities.h"
#import "Firebase/Messaging/NSError+FIRMessaging.h"



// register device with checkin
typedef void (^FIRMessagingRegisterDeviceHandler)(NSError *error);

@interface FIRMessagingClient ()

@property(nonatomic, readwrite, weak) id<FIRMessagingClientDelegate> clientDelegate;
@property(nonatomic, readonly, strong) FIRMessagingPubSubRegistrar *registrar;
@property(nonatomic, readwrite, strong) NSString *senderId;


@end

@implementation FIRMessagingClient

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithDelegate:(id<FIRMessagingClientDelegate>)delegate {
  self = [super init];
  if (self) {
    _clientDelegate = delegate;
    _registrar = [[FIRMessagingPubSubRegistrar alloc] init];
  }
  return self;
}

- (void)teardown {
  if (![NSThread isMainThread]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeClient000,
                            @"FIRMessagingClient should be called from main thread only.");
  }

  // Stop all subscription requests
  [self.registrar stopAllSubscriptionRequests];

  [NSObject cancelPreviousPerformRequestsWithTarget:self];

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cancelAllRequests {
  // Stop any checkin requests or any subscription requests
  [self.registrar stopAllSubscriptionRequests];

}

#pragma mark - FIRMessaging subscribe

- (void)updateSubscriptionWithToken:(NSString *)token
                              topic:(NSString *)topic
                            options:(NSDictionary *)options
                       shouldDelete:(BOOL)shouldDelete
                            handler:(FIRMessagingTopicOperationCompletion)handler {
  FIRMessagingTopicOperationCompletion completion = ^void(NSError *error) {
    if (error) {
      FIRMessagingLoggerError(kFIRMessagingMessageCodeClient001, @"Failed to subscribe to topic %@",
                              error);
    } else {
      if (shouldDelete) {
        FIRMessagingLoggerInfo(kFIRMessagingMessageCodeClient002,
                               @"Successfully unsubscribed from topic %@", topic);
      } else {
        FIRMessagingLoggerInfo(kFIRMessagingMessageCodeClient003,
                               @"Successfully subscribed to topic %@", topic);
      }
    }
    if (handler) {
      handler(error);
    }
  };

  if ([[FIRInstanceID instanceID] tryToLoadValidCheckinInfo]) {
    [self.registrar updateSubscriptionToTopic:topic
                                    withToken:token
                                      options:options
                                 shouldDelete:shouldDelete
                                      handler:completion];
  } else {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeRegistrar000,
                            @"Device check in error, no auth credentials found");
    NSError *error = [NSError errorWithFCMErrorCode:kFIRMessagingErrorCodeMissingDeviceID];
    handler(error);
  }
}





@end
