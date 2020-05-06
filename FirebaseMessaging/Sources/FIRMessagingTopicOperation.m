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

#import "FirebaseMessaging/Sources/FIRMessagingTopicOperation.h"

#import <FirebaseInstanceID/FIRInstanceID_Private.h>

#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"

static NSString *const kFIRMessagingSubscribeServerHost =
    @"https://iid.googleapis.com/iid/register";

NSString *FIRMessagingSubscriptionsServer() {
  static NSString *serverHost = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSDictionary *environment = [[NSProcessInfo processInfo] environment];
    NSString *customServerHost = environment[@"FCM_SERVER_ENDPOINT"];
    if (customServerHost.length) {
      serverHost = customServerHost;
    } else {
      serverHost = kFIRMessagingSubscribeServerHost;
    }
  });
  return serverHost;
}

@interface FIRMessagingTopicOperation () {
  BOOL _isFinished;
  BOOL _isExecuting;
}

@property(nonatomic, readwrite, copy) NSString *topic;
@property(nonatomic, readwrite, assign) FIRMessagingTopicAction action;
@property(nonatomic, readwrite, copy) NSString *token;
@property(nonatomic, readwrite, copy) NSDictionary *options;
@property(nonatomic, readwrite, copy) FIRMessagingTopicOperationCompletion completion;

@property(atomic, strong) NSURLSessionDataTask *dataTask;

@end

@implementation FIRMessagingTopicOperation

+ (NSURLSession *)sharedSession {
  static NSURLSession *subscriptionOperationSharedSession;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForResource = 60.0f;  // 1 minute
    subscriptionOperationSharedSession = [NSURLSession sessionWithConfiguration:config];
    subscriptionOperationSharedSession.sessionDescription = @"com.google.fcm.topics.session";
  });
  return subscriptionOperationSharedSession;
}

- (instancetype)initWithTopic:(NSString *)topic
                       action:(FIRMessagingTopicAction)action
                        token:(NSString *)token
                      options:(NSDictionary *)options
                   completion:(FIRMessagingTopicOperationCompletion)completion {
  if (self = [super init]) {
    _topic = topic;
    _action = action;
    _token = token;
    _options = options;
    _completion = completion;

    _isExecuting = NO;
    _isFinished = NO;
  }
  return self;
}

- (void)dealloc {
  _topic = nil;
  _token = nil;
  _completion = nil;
}

- (BOOL)isAsynchronous {
  return YES;
}

- (BOOL)isExecuting {
  return _isExecuting;
}

- (void)setExecuting:(BOOL)executing {
  [self willChangeValueForKey:@"isExecuting"];
  _isExecuting = executing;
  [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isFinished {
  return _isFinished;
}

- (void)setFinished:(BOOL)finished {
  [self willChangeValueForKey:@"isFinished"];
  _isFinished = finished;
  [self didChangeValueForKey:@"isFinished"];
}

- (void)start {
  if (self.isCancelled) {
    NSError *error = [NSError
        messagingErrorWithCode:kFIRMessagingErrorCodePubSubOperationIsCancelled
                 failureReason:
                     @"Failed to start the pubsub service as the topic operation is cancelled."];
    [self finishWithError:error];
    return;
  }

  [self setExecuting:YES];

  [self performSubscriptionChange];
}

- (void)finishWithError:(NSError *)error {
  // Add a check to prevent this finish from being called more than once.
  if (self.isFinished) {
    return;
  }
  self.dataTask = nil;
  if (self.completion) {
    self.completion(error);
  }

  [self setExecuting:NO];
  [self setFinished:YES];
}

- (void)cancel {
  [super cancel];
  [self.dataTask cancel];
  NSError *error = [NSError messagingErrorWithCode:kFIRMessagingErrorCodePubSubOperationIsCancelled
                                     failureReason:@"The topic operation is cancelled."];
  [self finishWithError:error];
}

- (void)performSubscriptionChange {
  NSURL *url = [NSURL URLWithString:FIRMessagingSubscriptionsServer()];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  NSString *appIdentifier = FIRMessagingAppIdentifier();
  NSString *deviceAuthID = [FIRInstanceID instanceID].deviceAuthID;
  NSString *secretToken = [FIRInstanceID instanceID].secretToken;
  NSString *authString = [NSString stringWithFormat:@"AidLogin %@:%@", deviceAuthID, secretToken];
  [request setValue:authString forHTTPHeaderField:@"Authorization"];
  [request setValue:appIdentifier forHTTPHeaderField:@"app"];
  [request setValue:[FIRInstanceID instanceID].versionInfo forHTTPHeaderField:@"info"];

  // Topic can contain special characters (like `%`) so encode the value.
  NSCharacterSet *characterSet = [NSCharacterSet URLQueryAllowedCharacterSet];
  NSString *encodedTopic =
      [self.topic stringByAddingPercentEncodingWithAllowedCharacters:characterSet];
  if (encodedTopic == nil) {
    // The transformation was somehow not possible, so use the original topic.
    FIRMessagingLoggerWarn(kFIRMessagingMessageCodeTopicOptionTopicEncodingFailed,
                           @"Unable to encode the topic '%@' during topic subscription change. "
                           @"Please ensure that the topic name contains only valid characters.",
                           self.topic);
    encodedTopic = self.topic;
  }

  NSMutableString *content = [NSMutableString
      stringWithFormat:@"sender=%@&app=%@&device=%@&"
                       @"app_ver=%@&X-gcm.topic=%@&X-scope=%@",
                       self.token, appIdentifier, deviceAuthID, FIRMessagingCurrentAppVersion(),
                       encodedTopic, encodedTopic];

  if (self.action == FIRMessagingTopicActionUnsubscribe) {
    [content appendString:@"&delete=true"];
  }

  FIRMessagingLoggerInfo(kFIRMessagingMessageCodeTopicOption000, @"Topic subscription request: %@",
                         content);

  request.HTTPBody = [content dataUsingEncoding:NSUTF8StringEncoding];
  [request setHTTPMethod:@"POST"];

  FIRMessaging_WEAKIFY(self) void (^requestHandler)(NSData *, NSURLResponse *, NSError *) =
      ^(NSData *data, NSURLResponse *URLResponse, NSError *error) {
        FIRMessaging_STRONGIFY(self) if (error) {
          // Our operation could have been cancelled, which would result in our data task's error
          // being NSURLErrorCancelled
          if (error.code == NSURLErrorCancelled) {
            // We would only have been cancelled in the -cancel method, which will call finish for
            // us so just return and do nothing.
            return;
          }
          FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTopicOption001,
                                  @"Device registration HTTP fetch error. Error Code: %ld",
                                  (long)error.code);
          [self finishWithError:error];
          return;
        }
        NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (response.length == 0) {
          NSString *failureReason = @"Invalid registration response - zero length.";
          FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTopicOperationEmptyResponse, @"%@",
                                  failureReason);
          [self finishWithError:[NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                                  failureReason:failureReason]];
          return;
        }
        NSArray *parts = [response componentsSeparatedByString:@"="];
        if (![parts[0] isEqualToString:@"token"] || parts.count <= 1) {
          NSString *failureReason = [NSString
              stringWithFormat:@"Invalid registration response :'%@'. It is missing 'token' field.",
                               response];
          FIRMessagingLoggerDebug(kFIRMessagingMessageCodeTopicOption002, @"%@", failureReason);
          [self finishWithError:[NSError messagingErrorWithCode:kFIRMessagingErrorCodeUnknown
                                                  failureReason:failureReason]];
          return;
        }
        [self finishWithError:nil];
      };

  NSURLSession *urlSession = [FIRMessagingTopicOperation sharedSession];

  self.dataTask = [urlSession dataTaskWithRequest:request completionHandler:requestHandler];
  NSString *description;
  if (_action == FIRMessagingTopicActionSubscribe) {
    description = [NSString stringWithFormat:@"com.google.fcm.topics.subscribe: %@", _topic];
  } else {
    description = [NSString stringWithFormat:@"com.google.fcm.topics.unsubscribe: %@", _topic];
  }
  self.dataTask.taskDescription = description;
  [self.dataTask resume];
}

@end
