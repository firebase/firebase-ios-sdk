/*
 * Copyright 2018 Google
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
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
// A class for handling action url following.
// It tries to handle these cases:
//    1 Follow a universal link.
//    2 Follow a custom url scheme link.
//    3 Follow other types of links.
@interface FIRIAMActionURLFollower : NSObject

// Create an FIRIAMActionURLFollower object by inspecting the app's main bundle info.
+ (instancetype)actionURLFollower;

- (instancetype)init NS_UNAVAILABLE;

// initialize the instance with an array of supported custom url schemes and
// the main application object
- (instancetype)initWithCustomURLSchemeArray:(NSArray<NSString *> *)customURLScheme
                             withApplication:(UIApplication *)application NS_DESIGNATED_INITIALIZER;

/**
 * Follow a given URL. Report success in the completion block parameter. Notice that
 * it can not always be fully sure about whether the operation is successful. So it's a clue
 * in some cases.
 * Check its implementation about the details in the following logic.
 */
- (void)followActionURL:(NSURL *)actionURL withCompletionBlock:(void (^)(BOOL success))completion;
@end
NS_ASSUME_NONNULL_END
