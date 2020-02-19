// Copyright 2019 Google
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

#define ABT_MSEC_PER_SEC 1000ull

#pragma mark - Keys for experiment dictionaries.

static NSString *const kABTExperimentDictionaryCreationTimestampKey = @"creationTimestamp";
static NSString *const kABTExperimentDictionaryExperimentIDKey = @"name";
static NSString *const kABTExperimentDictionaryExpiredEventKey = @"expiredEvent";
static NSString *const kABTExperimentDictionaryOriginKey = @"origin";
static NSString *const kABTExperimentDictionaryTimedOutEventKey = @"timedOutEvent";
static NSString *const kABTExperimentDictionaryTimeToLiveKey = @"timeToLive";
static NSString *const kABTExperimentDictionaryTriggeredEventKey = @"triggeredEvent";
static NSString *const kABTExperimentDictionaryTriggeredEventNameKey = @"triggerEventName";
static NSString *const kABTExperimentDictionaryTriggerTimeoutKey = @"triggerTimeout";
static NSString *const kABTExperimentDictionaryVariantIDKey = @"value";

#pragma mark - Keys for event dictionaries.

static NSString *const kABTEventDictionaryNameKey = @"name";
static NSString *const kABTEventDictionaryOriginKey = @"origin";
static NSString *const kABTEventDictionaryParametersKey = @"parameters";
static NSString *const kABTEventDictionaryTimestampKey = @"timestamp";
