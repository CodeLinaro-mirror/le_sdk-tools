#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

set -e

QIMSDK_SOCKET_LIST="${DISPLAY_SOCKET} ${CAMERA_SOCKET} ${AUDIO_SOCKET}"
SOCKET_GROUP=""
SOCKET_GID=""

for QIMSDK_SOCKET in ${QIMSDK_SOCKET_LIST} ; do
    # Check if socket exists
    if [ -e "${QIMSDK_SOCKET}" ]; then
        # Get the GID that owns the socket
        SOCKET_GID=$(stat -c '%g' ${QIMSDK_SOCKET})

        # Skip root group (GID 0) for security reasons
        if [ "${SOCKET_GID}" -eq 0 ]; then
            echo "INFO: Socket owned by root (GID 0). Skipping group setup for security reasons." >&2
        else
            # Check if a group with this GID already exists
            if ! getent group "${SOCKET_GID}" >/dev/null; then
                # Create group with matching GID
                SOCKET_GROUP="socket_${SOCKET_GID}"
                echo "INFO: Creating group '${SOCKET_GROUP}' with GID ${SOCKET_GID}" >&2
                groupadd -g "${SOCKET_GID}" "${SOCKET_GROUP}"
            else
                # Get the actual group name for this GID
                SOCKET_GROUP=$(getent group "${SOCKET_GID}" | cut -d: -f1)
                echo "INFO: Found existing group '${SOCKET_GROUP}' (GID ${SOCKET_GID})" >&2
            fi

            # Add qimsdk user to the group (no-op if already a member)
            echo "INFO: Adding qimsdk user to '${SOCKET_GROUP}' group" >&2
            usermod -a -G "${SOCKET_GROUP}" qimsdk
        fi
    fi
done

# Hand off to the container's main process
exec gosu qimsdk bash
