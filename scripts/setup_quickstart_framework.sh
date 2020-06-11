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

git clone https://github.com/firebase/quickstart-ios.git
cd quickstart-ios/"${SAMPLE}"
chmod +x ../scripts/info_script.rb
ruby ../scripts/info_script.rb "${SAMPLE}"

mkdir -p Firebase/
mv "${HOME}"/ios_frameworks/Firebase/Firebase.h Firebase/
mv "${HOME}"/ios_frameworks/Firebase/module.modulemap Firebase/
for file in "$@"
do
  mv '${file}' Firebase/
done
../scripts/add_framework_script.rb  "${SAMPLE}" "${TARGET}" Firebase
