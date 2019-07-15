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
#import "FIRIAMBookKeeper.h"
#import "FIRIAMFetchResponseParser.h"
#import "FIRIAMMessageDefinition.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRIAMServerMsgFetchStorage;
@class FIRIAMDisplayCheckOnAnalyticEventsFlow;

@interface FIRIAMContextualTrigger
@property(nonatomic, copy, readonly) NSString *eventName;
@end

@interface FIRIAMContextualTriggerListener
+ (void)listenForTriggers:(NSArray<FIRIAMContextualTrigger *> *)triggers
             withCallback:(void (^)(FIRIAMContextualTrigger *matchedTrigger))callback;
@end

@protocol FIRIAMCacheDataObserver
- (void)dataChanged;
@end

// This class serves as an in-memory cache of the messages that would be searched for finding next
// message to be rendered. Its content can be loaded from client persistent storage upon SDK
// initialization and then updated whenever a new fetch is made to server to receive the last
// list. In the case a message has been rendered, it's removed from the cache so that it's not
// considered next time for the message search.
//
// This class is also responsible for setting up and tearing down appropriate analytics event
// listening flow based on whether the current active event list contains any analytics event
// trigger based messages.
//
// This class exists so that we can do message match more efficiently (in-memory search vs search
// in local persistent storage) by using appropriate in-memory data structure.
@interface FIRIAMMessageClientCache : NSObject

// used to inform the analytics event display check flow about whether it should start/stop
// analytics event listening based on the latest message definitions
// make it weak to avoid retaining cycle
@property(nonatomic, weak, nullable)
    FIRIAMDisplayCheckOnAnalyticEventsFlow *analycisEventDislayCheckFlow;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBookkeeper:(id<FIRIAMBookKeeper>)bookKeeper
               usingResponseParser:(FIRIAMFetchResponseParser *)responseParser;

// set an observer for watching for data changes in the cache
- (void)setDataObserver:(id<FIRIAMCacheDataObserver>)observer;

// Returns YES if there are any test messages in the cache.
- (BOOL)hasTestMessage;

// read all the messages as a copy stored in cache
- (NSArray<FIRIAMMessageDefinition *> *)allRegularMessages;

// clients that are to display messages should use nextOnAppOpenDisplayMsg or
// nextOnFirebaseAnalyticEventDisplayMsg to fetch the next eligible message and use
// removeMessageWithId to remove it from cache once the message has been correctly rendered

// Fetch next eligible messages that are appropriate for display at app launch time
- (nullable FIRIAMMessageDefinition *)nextOnAppLaunchDisplayMsg;
// Fetch next eligible messages that are appropriate for display at app open time
- (nullable FIRIAMMessageDefinition *)nextOnAppOpenDisplayMsg;
// Fetch next eligible message that matches the event triggering condition
- (nullable FIRIAMMessageDefinition *)nextOnFirebaseAnalyticEventDisplayMsg:(NSString *)eventName;

// Call this after a message has been rendered to remove it from the cache.
- (void)removeMessageWithId:(NSString *)messgeId;

// reset messages data
- (void)setMessageData:(NSArray<FIRIAMMessageDefinition *> *)messages;
// load messages from persistent storage
- (void)loadMessageDataFromServerFetchStorage:(FIRIAMServerMsgFetchStorage *)fetchStorage
                               withCompletion:(void (^)(BOOL success))completion;
@end
NS_ASSUME_NONNULL_END
