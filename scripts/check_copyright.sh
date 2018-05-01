# Copyright 2018 Google
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Check source files for copyright notices

options=(
  -E  # Use extended regexps
  -I  # Exclude binary files
  -L  # Show files that don't have a match
  'Copyright [0-9]{4}.*Google'
)

git grep "${options[@]}" \
    -- '*.'{c,cc,h,js,m,mm,py,sh,swift} \
    ':(exclude)**/third_party/**'
if [[ $? == 0 ]]; then
  echo "ERROR: Missing copyright notices in the files above. Please fix."
  exit 1
fi

