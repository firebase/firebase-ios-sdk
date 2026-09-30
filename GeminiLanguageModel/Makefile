# Copyright 2026 Google LLC
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

# Convenience entry points for the gemini-for-foundation-models package. Each runs the
# same command the package's own workflow runs (.github/workflows/gemini-fm.yml), so a
# checkout can be built and tested without re-deriving the flag spelling.
#
# A toolchain that is not on PATH may be named explicitly:
#
#   make test SWIFT=/opt/swift-6.2.3/RELEASE/usr/bin/swift
#
# A swift.org Linux toolchain keeps its runtime libraries in its own lib directory, so
# that directory is derived from SWIFT and exported when it exists.

SWIFT ?= swift
SWIFT_FLAGS ?= -Xswiftc -warnings-as-errors
SWIFT_LIB := $(abspath $(dir $(SWIFT))..)/lib

ifneq ($(wildcard $(SWIFT_LIB)),)
export LD_LIBRARY_PATH := $(SWIFT_LIB)$(if $(LD_LIBRARY_PATH),:$(LD_LIBRARY_PATH))
endif

.PHONY: all build test test-live clean

all: build

build:
	$(SWIFT) build $(SWIFT_FLAGS)

test:
	$(SWIFT) test $(SWIFT_FLAGS)

# The live tests reach the real OrcaRouter origin and run only while
# ORCAROUTER_API_KEY is present; without it the run reports no matching cases.
test-live:
	$(SWIFT) test $(SWIFT_FLAGS) --filter OrcaRouterLiveTests

clean:
	$(SWIFT) package clean
