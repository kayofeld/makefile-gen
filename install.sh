#! /bin/bash
# Verify the script is being runned as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Verify ruby is installed
if ! type "ruby" > /dev/null; then
    echo "makefile-gen depends on ruby to work"
    exit 1
fi

# Copy the script to /usr/bin
cp srcs/makefile-gen.rb /usr/bin/makefile-gen
# Installing the man page
cp man/makefile-gen.1 /usr/share/man/man1/

echo "executable and man installed"
makefile-gen -h
