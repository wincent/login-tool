#!/bin/sh -e

# if run under Xcode, the -e in the shebang line will be ignored
set -e

sdef "/System/Library/CoreServices/System Events.app" | \
sdp -fh --basename SystemEvents

