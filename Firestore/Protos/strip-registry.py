#!/usr/bin/python

# Copyright 2017 Google
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""strip-registry.py removes extensionRegistry functions from objc protos.
"""

import sys

filename = sys.argv[1]

with open(filename) as input:
  content = [x.strip('\n') for x in input.readlines()]

if '+ (GPBExtensionRegistry*)extensionRegistry {' in content:
  new_content = []
  skip = False
  for line in content:
    if '+ (GPBExtensionRegistry*)extensionRegistry {' in line:
      skip = True
    if not skip:
      new_content.append(line)
    elif line == '}':
      skip = False

  with open(filename, "w") as output:
    output.write('\n'.join(new_content) + '\n')
