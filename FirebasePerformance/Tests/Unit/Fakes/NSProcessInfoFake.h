// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A fake for NSProcessInfo, used only for testing. */
@interface NSProcessInfoFake : NSProcessInfo

/** Required override of the processInfo class property. */
@property(class, readonly, strong) NSProcessInfoFake *processInfo;

/** A string to add to the arguments list returned by -arguments. */
@property(nullable, nonatomic) NSString *fakeArgument;

@end

NS_ASSUME_NONNULL_END
