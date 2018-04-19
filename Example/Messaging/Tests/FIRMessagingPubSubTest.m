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

#import <XCTest/XCTest.h>

#import "FIRMessagingPubSub.h"

@interface FIRMessagingPubSubTest : XCTestCase
@end

@implementation FIRMessagingPubSubTest

static NSString *const kTopicName = @"topic-Name";

#pragma mark - topicMatchForSender tests

/// Tests that an empty topic name is an invalid topic.
- (void)testTopicMatchForEmptyTopicPrefix {
  XCTAssertFalse([FIRMessagingPubSub isValidTopicWithPrefix:@""]);
}

/// Tests that a topic with an invalid prefix is not a valid topic name.
- (void)testTopicMatchWithInvalidTopicPrefix {
  XCTAssertFalse([FIRMessagingPubSub isValidTopicWithPrefix:@"/topics+abcdef/"]);
}

/// Tests that a topic with a valid prefix but invalid name is not a valid topic name.
- (void)testTopicMatchWithValidTopicPrefixButInvalidName {
  XCTAssertFalse([FIRMessagingPubSub isValidTopicWithPrefix:@"/topics/aaaaaa/topics/lala"]);
}

/// Tests that multiple backslashes in topics is an invalid topic name.
- (void)testTopicMatchForInvalidTopicPrefix_multipleBackslash {
  XCTAssertFalse([FIRMessagingPubSub isValidTopicWithPrefix:@"/topics//abc"]);
}

/// Tests a topic name with a valid prefix and name.
- (void)testTopicMatchForValidTopicSender {
  NSString *topic = [NSString stringWithFormat:@"/topics/%@", kTopicName];
  XCTAssertTrue([FIRMessagingPubSub isValidTopicWithPrefix:topic]);
}

/// Tests topic prefix for topics with no prefix.
- (void)testTopicHasNoTopicPrefix {
  XCTAssertFalse([FIRMessagingPubSub hasTopicsPrefix:@""]);
}

/// Tests topic prefix for valid prefix.
- (void)testTopicHasValidToicsPrefix {
  XCTAssertTrue([FIRMessagingPubSub hasTopicsPrefix:@"/topics/"]);
}

/// Tests topic prefix wih no prefix.
- (void)testAddTopicPrefix_withNoPrefix {
  NSString *topic = [FIRMessagingPubSub addPrefixToTopic:@""];
  XCTAssertTrue([FIRMessagingPubSub hasTopicsPrefix:topic]);
  XCTAssertFalse([FIRMessagingPubSub isValidTopicWithPrefix:topic]);
}

/// Tests adding the "/topics/" prefix for topic name which already has a prefix.
- (void)testAddTopicPrefix_withPrefix {
  NSString *topic = [NSString stringWithFormat:@"/topics/%@", kTopicName];
  topic = [FIRMessagingPubSub addPrefixToTopic:topic];
  XCTAssertTrue([FIRMessagingPubSub hasTopicsPrefix:topic]);
  XCTAssertTrue([FIRMessagingPubSub isValidTopicWithPrefix:topic]);
}

@end
