  #!/bin/bash

# Copyright 2020 Google LLC
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

output="$1"

git clone https://github.com/googleapis/google-auth-library-swift.git
cd google-auth-library-swift
git checkout --quiet 7b1c9cd4ffd8cb784bcd8b7fd599794b69a810cf # This commit will work.
make -f Makefile
#export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.credentials/ServiceAccount.json"
swift run TokenSource > $output
echo Access token generated!
cat $output
