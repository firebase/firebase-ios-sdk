#!/bin/sh

# $1 is the file to decrypt
# $2 is the output file
# $3 is teh passphrase

# Decrypt the file
# --batch to prevent interactive command --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="$3" \
--output $2 $1