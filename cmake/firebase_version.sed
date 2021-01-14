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

# USAGE:
# sed -n -f cmake/firebase_version.sed FirebaseCore.podspec

# Finds the Firebase version in the FirebaseCore podspec. Note this is *not*
# the FIRCore version.
#
# The line this looks for is this one:
#
#       s.version          = '7.0.0'

# Find the line passing the Firebase_VERSION macro.
/.* s.version.*=/ {
  # Re-use the pattern buffer to remove everything on the line up to and
  # including the =.
  s///

  # Remove the surrounding quotes
  s/'//
  s/'//

  # Explicitly print
  p
}
