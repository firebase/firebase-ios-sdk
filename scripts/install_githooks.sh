# Copyright 2019 Google
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
#
# This script sets up the git hooks on the developer's machine 

gitRoot=$(git rev-parse --show-toplevel)
source=$(echo "/$gitRoot/scripts/git-hooks/.")
dest=$(echo "/$gitRoot/.git/hooks")

cp -a -f /$gitRoot/scripts/git-hooks/. /$gitRoot/.git/hooks

echo >&2 "Copying files from $source to $dest"

exitCode=$?
if [[ $exitCode -eq 0 ]]; then
  echo >&2 "Installed githooks."
else 
  echo >&2 "Failed to install githooks: $exitCode" 
  exit 1
fi

exit 0
