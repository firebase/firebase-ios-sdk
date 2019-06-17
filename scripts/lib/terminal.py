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

import subprocess
import threading


_lock = threading.Lock()
_columns = None


def columns():
  """Returns the number of columns in the terminal's display."""

  global _columns
  with _lock:
    if _columns is None:
      _columns = _find_terminal_columns()
    return _columns


def _find_terminal_columns():
  try:
    result = subprocess.check_output(['tput', 'cols'])
    return int(result.rstrip())
  except subprocess.CalledProcessError:
    return 80
