/*
 * Copyright 2024 Google LLC
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

#import "FIRMessaging.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRMessagingExtensionHelper;

@interface FIRMessaging (ExtensionHelper)

/**
 * Use the MessagingExtensionHelper to populate rich UI content for your notifications.
 * For example, if an image URL is set in your notification payload or on the console,
 * you can use the MessagingExtensionHelper instance returned from this method to render
 * the image in your notification.
 *
 * @return An instance of MessagingExtensionHelper that handles the extensions API.
 */
+ (FIRMessagingExtensionHelper *)extensionHelper NS_SWIFT_NAME(serviceExtension());

@end

NS_ASSUME_NONNULL_END
