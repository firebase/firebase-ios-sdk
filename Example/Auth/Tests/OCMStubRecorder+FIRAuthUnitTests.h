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

#import <OCMock/OCMStubRecorder.h>

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRAuthGeneralBlock2
    @brief A general block that takes two nullable ids and returns nothing.
 */
typedef void (^FIRAuthGeneralBlock2)(id _Nullable, id _Nullable);

/** @category OCMStubRecorder(FIRAuthUnitTests)
    @brief Utility methods and properties use by Firebase Auth unit tests.
 */
@interface OCMStubRecorder (FIRAuthUnitTests)

/** @fn andCallBlock2
    @brief Calls a general block that takes two parameters as the action of the stub.
    @param block2 A block that takes exactly two 'id'-compatible parameters.
    @remarks The method being stubbed must take exactly two parameters, both of which must be
        compatible with type 'id'.
 */
- (id)andCallBlock2:(FIRAuthGeneralBlock2)block2;

/** @fn andDispatchError2
    @brief Dispatchs an error to the second callback parameter in the global auth work queue.
    @param error The error to call back as the second argument to the second parameter block.
    @remarks The method being stubbed must take exactly two parameters, the first of which must be
        compatible with type 'id' and the second of which must be a block that takes an
        'id'-compatible parameter and an NSError* parameter.
 */
- (id)andDispatchError2:(NSError *)error;

// This macro allows .andCallBlock2 shorthand to match established style of OCMStubRecorder.
#define andCallBlock2(block2) _andCallBlock2(block2)

// This macro allows .andDispatchError2 shorthand to match established style of OCMStubRecorder.
#define andDispatchError2(block2) _andDispatchError2(block2)

/** @property _andCallBlock2
    @brief A block that calls @c andCallBlock2: method on self.
 */
@property(nonatomic, readonly) OCMStubRecorder *(^ _andCallBlock2)(FIRAuthGeneralBlock2);

/** @property _andDispatchError2
    @brief A block that calls @c andDispatchError2: method on self.
 */
@property(nonatomic, readonly) OCMStubRecorder *(^ _andDispatchError2)(NSError *);

@end

NS_ASSUME_NONNULL_END
