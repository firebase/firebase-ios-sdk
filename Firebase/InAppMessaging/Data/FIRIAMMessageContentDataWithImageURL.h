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

#import "FIRIAMMessageContentData.h"

NS_ASSUME_NONNULL_BEGIN
/**
 * An implementation for protocol FIRIAMMessageContentData. This class takes a image url
 * and fetch it over the network to retrieve the image data.
 */
@interface FIRIAMMessageContentDataWithImageURL : NSObject <FIRIAMMessageContentData>
/**
 * Create an instance which uses NSURLSession to do the image data fetching.
 *
 * @param title Message title text.
 * @param body Message body text.
 * @param actionButtonText Text for action button.
 * @param actionURL url string for action.
 * @param imageURL  the url to the image. It can be nil to indicate the non-image in-app
 *                  message case.
 * @param URLSession can be nil in which case the class would create NSURLSession
 *                   internally to perform the network request. Having it here so that
 *                   it's easier for doing mocking with unit testing.
 */
- (instancetype)initWithMessageTitle:(NSString *)title
                         messageBody:(NSString *)body
                    actionButtonText:(nullable NSString *)actionButtonText
           secondaryActionButtonText:(nullable NSString *)secondaryActionButtonText
                           actionURL:(nullable NSURL *)actionURL
                  secondaryActionURL:(nullable NSURL *)secondaryActionURL
                            imageURL:(nullable NSURL *)imageURL
                   landscapeImageURL:(nullable NSURL *)landscapeImageURL
                     usingURLSession:(nullable NSURLSession *)URLSession;
@end
NS_ASSUME_NONNULL_END
