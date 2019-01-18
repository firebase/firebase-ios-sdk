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

#import "GDLRegistrar.h"

NS_ASSUME_NONNULL_BEGIN

/** This class connects log storage and the uploader implementations, providing logs to an uploader
 * and informing the log storage what logs were successfully uploaded or not.
 */
@interface GDLUploadCoordinator : NSObject

/** Creates and/or returrns the singleton.
 *
 * @return The singleton instance of this class.
 */
+ (instancetype)sharedInstance;

/** Forces the backend specified by the target to upload the provided set of logs. This should only
 * ever happen when the QoS tier of a log requires it.
 *
 * @param logHashes The set of log hashes to force upload.
 * @param logTarget The log target that should force an upload.
 */
- (void)forceUploadLogs:(NSSet<NSNumber *> *)logHashes target:(GDLLogTarget)logTarget;

@end

NS_ASSUME_NONNULL_END
