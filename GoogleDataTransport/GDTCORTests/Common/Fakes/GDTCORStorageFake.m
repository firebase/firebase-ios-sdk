/*
 * Copyright 2019 Google
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

#import "GDTCORTests/Common/Fakes/GDTCORStorageFake.h"

@implementation GDTCORStorageFake

- (void)storeEvent:(GDTCOREvent *)event
        onComplete:(void (^_Nullable)(BOOL wasWritten, NSError *_Nullable))completion {
  if (completion) {
    completion(YES, nil);
  }
}

- (void)removeEvents:(NSSet<NSNumber *> *)eventIDs {
}

- (void)libraryDataForKey:(nonnull NSString *)key
               onComplete:
                   (nonnull void (^)(NSData *_Nullable, NSError *_Nullable error))onComplete {
  if (onComplete) {
    onComplete(nil, nil);
  }
}

- (void)storeLibraryData:(NSData *)data
                  forKey:(nonnull NSString *)key
              onComplete:(nonnull void (^)(NSError *_Nullable error))onComplete {
  if (onComplete) {
    onComplete(nil);
  }
}

- (void)removeLibraryDataForKey:(nonnull NSString *)key
                     onComplete:(nonnull void (^)(NSError *_Nullable))onComplete {
  if (onComplete) {
    onComplete(nil);
  }
}

@end
