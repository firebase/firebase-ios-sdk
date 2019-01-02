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

#include <initializer_list>
#include <string>

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"

// Using forward declaration to avoid circular dependency (`document_key.h` includes this header).`
namespace firebase {
namespace firestore {
namespace model {
class DocumentKey;
}
}
}

NS_ASSUME_NONNULL_BEGIN

/**
 * `FSTDocumentKey` is a thin wrapper over `DocumentKey`, necessary until full migration is
 * possible. Use the underlying `DocumentKey` for any operations.
 */
@interface FSTDocumentKey : NSObject <NSCopying>

+ (instancetype)keyWithDocumentKey:(const firebase::firestore::model::DocumentKey &)documentKey;

/** Gets the underlying C++ representation. */
- (const firebase::firestore::model::DocumentKey &)key;

@end

/** The field path string that represents the document's key. */
extern NSString *const kDocumentKeyPath;

NS_ASSUME_NONNULL_END
