#!/bin/bash
find . \
    -name 'third_party' -prune -o \
    -name 'Auth' -prune -o \
    -name 'AuthSamples' -prune -o \
    -name 'Database' -prune -o \
    -name 'Messaging' -prune -o \
    -name 'Storage' -prune -o \
    -name '*.[mh]' \
    -not -name '*.pbobjc.*' \
    -exec clang-format -style=file -i '{}' \;
