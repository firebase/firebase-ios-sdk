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


TASKS = multiprocessing.cpu_count()


_output_lock = threading.Lock()


def chunks(items, n):
  """Yield successive n-sized chunks from items."""
  for i in range(0, len(items), n):
    yield items[i:i + n]


def shard(items):
  if not items:
    return []

  n = int(math.ceil(len(items) / TASKS))
  return chunks(items, n)


class Result(object):

  def __init__(self, errors, output):
    self.errors = errors
    self.output = output

  @staticmethod
  def from_list(errors):
    return Result(len(errors), '\n'.join(errors))


class Pool(object):

  def __init__(self):
    self.pending = queue.Queue()
    self.results = queue.Queue()

    def worker():
      while True:
        task, args = self.pending.get()
        result = task(*args)
        if result is not None:
          self.results.put(result)
        self.pending.task_done()

    for i in range(TASKS):
      t = threading.Thread(target=worker)
      t.daemon = True
      t.start()

  def submit(self, task, *args):
    self.pending.put((task, args))

  def join(self):
    self.pending.join()

    errors = 0
    while not self.results.empty():
      result = self.results.get()
      errors += result.errors
      sys.stdout.write(result.output)
      self.results.task_done()

    self.results.join()
    return errors

  def exit(self):
    errors = self.join()
    sys.exit(errors > 0)
