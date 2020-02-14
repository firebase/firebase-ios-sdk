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

#import <GoogleDataTransport/GDTCOREvent.h>

#import <GoogleDataTransport/GDTCORClock.h>

NS_ASSUME_NONNULL_BEGIN

@interface GDTCOREvent ()

/** Writes [dataObject transportBytes] to the given URL, populates fileURL with the filename, then
 * nils the dataObject property. This method should not be called twice on the same event.
 *
 * @param fileURL The fileURL that dataObject will be written to.
 * @param error If populated, the error encountered during writing to disk.
 * @return YES if writing dataObject to disk was successful, NO otherwise.
 */
- (BOOL)writeToURL:(NSURL *)fileURL error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
