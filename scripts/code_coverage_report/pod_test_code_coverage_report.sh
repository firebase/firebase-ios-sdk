# Copyright 2021 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SDK="$1"
platform="$2"
if [ -d "/Users/runner/Library/Developer/Xcode/DerivedData" ]; then
rm -r /Users/runner/Library/Developer/Xcode/DerivedData/*
fi
scripts/third_party/travis/retry.sh scripts/pod_lib_lint.rb "${SDK}".podspec --platforms="${platform}" --test-specs=unit
find /Users/runner/Library/Developer/Xcode/DerivedData -type d -regex ".*/.*\.xcresult" -execdir cp -R '{}' "/Users/runner/ "${SDK}"-"${platform}".xcresult" \;

