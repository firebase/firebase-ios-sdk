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
#import "OCMStubRecorder.h"

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRAuthGeneralBlock1
    @brief A general block that takes one id and returns nothing.
 */
typedef void (^FIRAuthGeneralBlock1)(id);

/** @typedef FIRAuthGeneralBlock2
    @brief A general block that takes two nullable ids and returns nothing.
 */
typedef void (^FIRAuthGeneralBlock2)(id _Nullable, id _Nullable);

/** @typedef FIRAuthIdDoubleIdBlock
    @brief A block that takes third parameters with types @c id, @c double, and @c id .
 */
typedef void (^FIRAuthIdDoubleIdBlock)(id, double, id);

/** @category OCMStubRecorder(FIRAuthUnitTests)
    @brief Utility methods and properties use by Firebase Auth unit tests.
 */
@interface OCMStubRecorder (FIRAuthUnitTests)

/** @fn andCallBlock1
    @brief Calls a general block that takes one parameter as the action of the stub.
    @param block1 A block that takes exactly one 'id'-compatible parameter.
    @remarks The method being stubbed must take exactly one parameter, which must be
        compatible with type 'id'.
 */
- (id)andCallBlock1:(FIRAuthGeneralBlock1)block1;

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

/** @fn andCallIdDoubleIdBlock:
    @brief Calls a block that takes three parameters as the action of the stub.
    @param block A block that takes exactly three parameters as described.
    @remarks The method being stubbed must take exactly three parameters. Its first and the third
        parameters must be compatible with type 'id' and its second parameter must be a 'double'.
 */
- (id)andCallIdDoubleIdBlock:(FIRAuthIdDoubleIdBlock)block;

// This macro allows .andCallBlock1 shorthand to match established style of OCMStubRecorder.
#define andCallBlock1(block1) _andCallBlock1(block1)

// This macro allows .andCallBlock2 shorthand to match established style of OCMStubRecorder.
#define andCallBlock2(block2) _andCallBlock2(block2)

// This macro allows .andDispatchError2 shorthand to match established style of OCMStubRecorder.
#define andDispatchError2(block2) _andDispatchError2(block2)

// This macro allows .andCallIdDoubleIdBlock shorthand to match established style of
// OCMStubRecorder.
#define andCallIdDoubleIdBlock(block) _andCallIdDoubleIdBlock(block)

/** @property _andCallBlock1
    @brief A block that calls @c andCallBlock1: method on self.
 */
@property(nonatomic, readonly) OCMStubRecorder * (^_andCallBlock1)(FIRAuthGeneralBlock1);

/** @property _andCallBlock2
    @brief A block that calls @c andCallBlock2: method on self.
 */
@property(nonatomic, readonly) OCMStubRecorder * (^_andCallBlock2)(FIRAuthGeneralBlock2);

/** @property _andDispatchError2
    @brief A block that calls @c andDispatchError2: method on self.
 */
@property(nonatomic, readonly) OCMStubRecorder * (^_andDispatchError2)(NSError *);

/** @property _andCallIdDoubleIdBlock
    @brief A block that calls @c andCallBlock2: method on self.
 */
@property(nonatomic, readonly) OCMStubRecorder * (^_andCallIdDoubleIdBlock)(FIRAuthIdDoubleIdBlock);

@end

NS_ASSUME_NONNULL_END
