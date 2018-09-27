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

// Use a bridge header file to pull in the in-app messaging display dependency
// so that the project still compiles when we don't do use_framework! in
// pod file: needed for unit testing with static library mode.
#ifndef BridgeHeader_h
#define BridgeHeader_h

#import "FIRIAMDefaultDisplayImpl.h"

#endif /* BridgeHeader_h */
