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

NS_ASSUME_NONNULL_BEGIN
/**
 * This protocol models the message content (non-ui related) data for an in-app message.
 */
@protocol FIRIAMMessageContentData
@property(nonatomic, readonly, nonnull) NSString *titleText;
@property(nonatomic, readonly, nonnull) NSString *bodyText;
@property(nonatomic, readonly, nullable) NSString *actionButtonText;
@property(nonatomic, readonly, nullable) NSURL *actionURL;
@property(nonatomic, readonly, nullable) NSURL *imageURL;

// Load image data and report the result in the callback block.
// Expect these cases in the callback block
// If error happens, error parameter will be non-nil.
// If no error happens and imageData parameter is nil, it indicates the case that there
// is no image assoicated with the message.
// If error is nil and imageData is not nil, then the image data is loaded successfully
- (void)loadImageDataWithBlock:(void (^)(NSData *_Nullable imageData,
                                         NSError *_Nullable error))block;

// convert to a description string of the content
- (NSString *)description;
@end
NS_ASSUME_NONNULL_END
