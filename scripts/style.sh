#!/bin/bash
find ./Firebase \
    -name 'third_party' -prune -o \
    -name '*.[mh]' \
    -not -name '*.pbobjc.*' \
    -exec clang-format -style=file -i '{}' \;
