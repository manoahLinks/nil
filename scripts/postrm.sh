#!/bin/sh
set -e

case "$1" in
    remove|purge)
        echo "Cleaning up rollup-bridge-contracts..."
        rm -rf /usr/share/rollup-bridge-contracts
        ;;
esac

exit 0

