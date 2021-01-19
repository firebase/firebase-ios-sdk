# Copyright 2021 Google LLC
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

DATABASE_PATHS=("FirebaseDatabase.*" \
  ".github/workflows/database\\.yml" \
  "Example/Database/" \
  "Interop/Auth/Public/\.\*.h")
FUNCTIONS_PATHS=("Functions.*" \
  ".github/workflows/functions\\.yml" \
  "Interop/Auth/Public/\.\*.h" \
  "FirebaseMessaging/Sources/Interop/\.\*.h")
echo "::set-output name=database_run_job::false"
echo "::set-output name=functions_run_job::false"
# Get most rescent ancestor commit.
common_commit=$(git merge-base remotes/origin/${pr_branch} remotes/origin/master)
echo "The common commit is ${common_commit}."

echo "=============== list changed files ==============="
cat < <(git diff --name-only $common_commit remotes/origin/${pr_branch})
echo "========== check paths of changed files =========="
git diff --name-only $common_commit HEAD > files.txt

touch run_sdk_jobs.txt
while IFS= read -r file
do
  echo $file
  for path in "${DATABASE_PATHS[@]}"
  do
    if [[ "${file}" =~ $path ]]; then
      echo "This file is updated under the path, ${path}"
      #echo "::set-output name=database_run_job::true" >> run_sdk_jobs.txt
      echo "database" >> run_sdk_jobs.txt
      cat run_sdk_jobs.txt
      break
    fi
  done
  for path in "${FUNCTIONS_PATHS[@]}"
  do
    if [[ "${file}" =~ $path ]]; then
      echo "This file is updated under the path, ${path}"
      #echo "::set-output name=functions_run_job::true" >> run_sdk_jobs.txt
      break
    fi
  done
done < files.txt

echo "=============== Updated jobs to be triggered ================="
cat ./run_sdk_jobs.txt
echo "=============== Update variables ================="
while IFS= read -r run_sdk
do
  echo "${run_sdk}"
  echo "::set-output name=${run_sdk}_run_job::true"
done < ./run_sdk_jobs.txt
