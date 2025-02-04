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

#import "FirebaseDatabase/Sources/Utilities/FUtilities.h"
#if !TARGET_OS_WATCH
#import "FirebaseDatabase/Sources/third_party/SocketRocket/FSRWebSocket.h"
#endif // !TARGET_OS_WATCH
#import <Foundation/Foundation.h>

@protocol FWebSocketDelegate;

#if !TARGET_OS_WATCH
@interface FWebSocketConnection
    : NSObject <FSRWebSocketDelegate, NSURLSessionWebSocketDelegate>
#else
@interface FWebSocketConnection : NSObject <NSURLSessionWebSocketDelegate>
#endif // else !TARGET_OS_WATCH

@property(nonatomic, weak) id<FWebSocketDelegate> delegate;

- (instancetype)initWith:(FRepoInfo *)repoInfo
                andQueue:(dispatch_queue_t)queue
             googleAppID:(NSString *)googleAppID
           lastSessionID:(NSString *)lastSessionID
           appCheckToken:(NSString *)appCheckToken;

- (void)open;
- (void)close;
- (void)start;
- (void)send:(NSDictionary *)dictionary;

// Ignore FSRWebSocketDelegate calls on watchOS.
#if !TARGET_OS_WATCH
- (void)webSocket:(FSRWebSocket *)webSocket didReceiveMessage:(id)message;

// Exclude the `webSocket` argument since it isn't used in this codebase and it
// allows for better code sharing with watchOS.
- (void)webSocketDidOpen;
- (void)webSocket:(FSRWebSocket *)webSocket didFailWithError:(NSError *)error;
- (void)webSocket:(FSRWebSocket *)webSocket
    didCloseWithCode:(NSInteger)code
              reason:(NSString *)reason
            wasClean:(BOOL)wasClean;
#endif // !TARGET_OS_WATCH

@end

@protocol FWebSocketDelegate <NSObject>

- (void)onMessage:(FWebSocketConnection *)fwebSocket
      withMessage:(NSDictionary *)message;
- (void)onDisconnect:(FWebSocketConnection *)fwebSocket
    wasEverConnected:(BOOL)everConnected;

@end
