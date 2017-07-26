#!/bin/bash
find . \
    -name 'third_party' -prune -o \
    -name 'Auth' -prune -o \
    -name 'AuthSamples' -prune -o \
    -name 'Database' -prune -o \
    -name 'FirebaseCommunity.h' -prune -o \
    -name 'Messaging' -prune -o \
    -name 'Storage' -prune -o \
    -name 'Pods' -prune -o \
    -name '*.[mh]' \
    -not -name '*.pbobjc.*' \
    -print0 | xargs -0 clang-format -style=file -i
