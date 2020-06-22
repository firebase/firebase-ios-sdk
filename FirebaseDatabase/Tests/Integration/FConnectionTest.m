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

#import <Foundation/Foundation.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Realtime/FConnection.h"
#import "FirebaseDatabase/Tests/Helpers/FTestBase.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

@interface FConnectionTest : FTestBase

@end

@interface FTestConnectionDelegate : NSObject <FConnectionDelegate>

@property(nonatomic, copy) void (^onReady)(NSString *);
@property(nonatomic, copy) void (^onDisconnect)(FDisconnectReason);

@end

@implementation FTestConnectionDelegate

- (void)onReady:(FConnection *)fconnection
         atTime:(NSNumber *)timestamp
      sessionID:(NSString *)sessionID {
  self.onReady(sessionID);
}
- (void)onDataMessage:(FConnection *)fconnection withMessage:(NSDictionary *)message {
}
- (void)onDisconnect:(FConnection *)fwebSocket withReason:(FDisconnectReason)reason {
  self.onDisconnect(reason);
}
- (void)onKill:(FConnection *)fconnection withReason:(NSString *)reason {
}

@end
@implementation FConnectionTest

- (void)XXXtestObtainSessionId {
  NSString *host =
      [NSString stringWithFormat:@"%@.firebaseio.com", [[FIRApp defaultApp] options].projectID];
  FRepoInfo *info = [[FRepoInfo alloc] initWithHost:host isSecure:YES withNamespace:@"default"];
  FConnection *conn = [[FConnection alloc] initWith:info
                                   andDispatchQueue:[FIRDatabaseQuery sharedQueue]
                                        googleAppID:@"fake-app-id"
                                      lastSessionID:nil];
  FTestConnectionDelegate *delegate = [[FTestConnectionDelegate alloc] init];

  __block BOOL done = NO;

  delegate.onDisconnect = ^(FDisconnectReason reason) {
    if (reason == DISCONNECT_REASON_SERVER_RESET) {
      // It is very likely that the first connection attempt sends us a redirect to the project's
      // designated server. We need follow that redirect before 'onReady' is invoked.
      [conn open];
    }
  };
  delegate.onReady = ^(NSString *sessionID) {
    NSAssert(sessionID, @"sessionID cannot be null");
    NSAssert([sessionID length] != 0, @"sessionID must have length > 0");
    done = YES;
  };

  conn.delegate = delegate;
  [conn open];

  WAIT_FOR(done);
}
@end
