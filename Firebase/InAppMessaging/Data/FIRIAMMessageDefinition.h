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

#import "FIRIAMDisplayTriggerDefinition.h"
#import "FIRIAMMessageRenderData.h"

@class FIRIAMDisplayTriggerDefinition;

NS_ASSUME_NONNULL_BEGIN
@interface FIRIAMMessageDefinition : NSObject
@property(nonatomic, nonnull, readonly) FIRIAMMessageRenderData *renderData;

// metadata data that does not affect the rendering content/effect directly
@property(nonatomic, readonly) NSTimeInterval startTime;
@property(nonatomic, readonly) NSTimeInterval endTime;

// a fiam message can have multiple triggers and any of them on its own can cause
// the message to be rendered
@property(nonatomic, readonly) NSArray<FIRIAMDisplayTriggerDefinition *> *renderTriggers;

/// A flag for client-side testing messages
@property(nonatomic, readonly) BOOL isTestMessage;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Create a regular message definition.
 */
- (instancetype)initWithRenderData:(FIRIAMMessageRenderData *)renderData
                         startTime:(NSTimeInterval)startTime
                           endTime:(NSTimeInterval)endTime
                 triggerDefinition:(NSArray<FIRIAMDisplayTriggerDefinition *> *)renderTriggers;

/**
 * Create a test message definition.
 */
- (instancetype)initTestMessageWithRenderData:(FIRIAMMessageRenderData *)renderData;

- (BOOL)messageHasExpired;
- (BOOL)messageHasStarted;

// should this message be rendered given the FIAM trigger type? only use this method for app launch
// and foreground trigger, use messageRenderedOnAnalyticsEvent: for analytics triggers
- (BOOL)messageRenderedOnTrigger:(FIRIAMRenderTrigger)trigger;
// should this message be rendered when a given analytics event is fired?
- (BOOL)messageRenderedOnAnalyticsEvent:(NSString *)eventName;
@end
NS_ASSUME_NONNULL_END
