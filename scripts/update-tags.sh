#!/usr/bin/env bash

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

# Update the tags for the Firebase 5.0.0 release process

# Before running, make sure everything is pushed.

# This script should be a spec for a more robust Python or Swift script that
# does the following.
# 1. Verify all files are committed
# 2. Verify running on a release branch
# 3. Read the versions from the podspec (or incorporate into even more
#    automated version management)

# Delete any existing tags at origin

git push --delete origin '5.2.0'
git push --delete origin 'Core-5.0.3'
git push --delete origin 'Auth-5.0.1'
#git push --delete origin 'Database-5.0.1'
git push --delete origin 'Firestore-0.12.3'
#git push --delete origin 'Functions-2.0.0'
git push --delete origin 'Messaging-3.0.2'
#git push --delete origin 'Storage-3.0.0'

# Delete local tags

git tag --delete '5.2.0'
git tag --delete 'Core-5.0.3'
git tag --delete 'Auth-5.0.1'
#git tag --delete 'Database-5.0.1'
git tag --delete 'Firestore-0.12.3'
#git tag --delete 'Functions-2.0.0'
git tag --delete 'Messaging-3.0.2'
#git tag --delete 'Storage-3.0.0'

# Add and push the tags

git tag '5.2.0'
git tag 'Core-5.0.3'
git tag 'Auth-5.0.1'
# git tag 'Database-5.0.1'
git tag 'Firestore-0.12.3'
#git tag 'Functions-2.0.0'
git tag 'Messaging-3.0.2'
#git tag 'Storage-3.0.0'

git push origin --tags
