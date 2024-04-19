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

#ifndef RCNConfigDefines_h
#define RCNConfigDefines_h

#if defined(DEBUG)
#define RCN_MUST_NOT_BE_MAIN_THREAD()                                                 \
  do {                                                                                \
    NSAssert(![NSThread isMainThread], @"Must not be executing on the main thread."); \
  } while (0);
#else
#define RCN_MUST_NOT_BE_MAIN_THREAD() \
  do {                                \
  } while (0);
#endif

#define RCNExperimentTableKeyPayload "experiment_payload"
#define RCNExperimentTableKeyMetadata "experiment_metadata"
#define RCNExperimentTableKeyActivePayload "experiment_active_payload"
#define RCNRolloutTableKeyActiveMetadata "active_rollout_metadata"
#define RCNRolloutTableKeyFetchedMetadata "fetched_rollout_metadata"

#endif
