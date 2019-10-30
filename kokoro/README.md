# Kokoro CI jobs and testing scripts

Firebase uses a Google-internal continuous integration tool called "Kokoro"
(a.k.a "internal CI") for running majority of its open source tests. This
directory contains the external part of kokoro test job configurations (the
actual job definitions live in Google's internal monorepo) and the shell
scripts that act as entry points to execute the actual tests.

## Adding a kokoro job

Each cfg file in the prod kokoro configuration directory (or any subdirectories)
is a distinct job. To add a new job, submit a CL with your new cfg file in
google3 and then submit a PR to this repository with a corresponding test script
in this directory. See the google-internal Firebase iOS docs for more details.
