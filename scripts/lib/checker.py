# Copyright 2019 Google LLC
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

from __future__ import division

import math
import multiprocessing.pool
import sys
import threading

# Python 3 renamed Queue to queue
try:
  import queue
except ImportError:
  import Queue as queue


_TASKS = multiprocessing.cpu_count()


_output_lock = threading.Lock()


def shard(items):
  """Breaks down the given items into roughly equal sized lists.

  The number of lists will be equal to the number of available processor cores.
  """
  if not items:
    return []

  n = int(math.ceil(len(items) / _TASKS))
  return _chunks(items, n)


def _chunks(items, n):
  """Yield successive n-sized chunks from items."""
  for i in range(0, len(items), n):
    yield items[i:i + n]


class Result(object):

  def __init__(self, num_errors, output):
    self.errors = num_errors
    self.output = (output
                   if isinstance(output, str)
                   else output.decode('utf8', errors='replace'))

  @staticmethod
  def from_list(errors):
    return Result(len(errors), '\n'.join(errors))


class Pool(object):

  def __init__(self):
    # Checkers submit tasks to be run and these are dropped in the _pending
    # queue. Workers process that queue and results are put in the _results
    # queue. _results is drained by the thread that calls join().
    self._pending = queue.Queue()
    self._results = queue.Queue()

    def worker():
      while True:
        task, args = self._pending.get()
        result = task(*args)
        if result is not None:
          self._results.put(result)
        self._pending.task_done()

    for i in range(_TASKS):
      t = threading.Thread(target=worker)
      t.daemon = True
      t.start()

  def submit(self, task, *args):
    """Submits a task for execution by the pool.

    Args:
      task: A callable routine that will perform the work.
      *args: A list of arguments to pass that routine.
    """
    self._pending.put((task, args))

  def join(self):
    """Waits for the completion of all submitted tasks.

    Returns:
      The number of errors encountered.
    """
    self._pending.join()

    num_errors = 0
    while not self._results.empty():
      result = self._results.get()
      num_errors += result.errors
      sys.stdout.write(result.output)
      self._results.task_done()

    self._results.join()
    return num_errors

  def exit(self):
    """Waits for the completion of the submitted tasks and exits.

    This calls join() and then exits with a 0 status code if there were no
    errors, or 1 if there were.
    """
    errors = self.join()
    sys.exit(errors > 0)
