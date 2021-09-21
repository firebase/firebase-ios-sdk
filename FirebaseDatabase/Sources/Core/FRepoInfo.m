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

// XXX STILL TODO:
//@interface FRepoInfo ()
//
//- (id)copyWithZone:(NSZone *)zone {
//    return self; // Immutable
//}
//
//- (NSUInteger)hash {
//    NSUInteger result = _host.hash;
//    result = 31 * result + (_secure ? 1 : 0);
//    result = 31 * result + _namespace.hash;
//    result = 31 * result + _host.hash;
//    return result;
//}
//
//- (BOOL)isEqual:(id)anObject {
//    if (![anObject isKindOfClass:[FRepoInfo class]]) {
//        return NO;
//    }
//    FRepoInfo *other = (FRepoInfo *)anObject;
//    return _secure == other.secure && [_host isEqualToString:other.host] &&
//           [_namespace isEqualToString:other.namespace];
//}
//
//@end
