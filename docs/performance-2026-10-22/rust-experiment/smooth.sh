#!/bin/sh
set -eu
exec /tmp/isla-cava-b/target/release/isla-cava-stream --smooth "$@"
