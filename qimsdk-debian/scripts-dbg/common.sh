#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function print-red() {
    tput setaf 1 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-green() {
    tput setaf 2 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-yellow() {
    tput setaf 3 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

function print-blue() {
    tput setaf 4 2>/dev/null
    echo $@
    tput sgr0 2>/dev/null
    true
}

# Argument count function validator helper
#   $1 - (mandatory) actual calling function argument count - allowed
# to be equal or higher than the value of the expected argument count
#   $2 - (mandatory) expected calling function argument count
function qimsdk-arg-count-check() {
    [ $# -ne 2 ] && print-red "${FUNCNAME[0]}: two arguments needed!" && return -1

    ! [[ "$1" =~ ^[0-9]{1,2}$ ]]                                                                && \
        print-red "${FUNCNAME[0]}: first argument must be a non-signed number!" && return -1

    ! [[ "$2" =~ ^[0-9]{1,2}$ ]]                                                                && \
        print-red "${FUNCNAME[0]}: second argument must be a non-signed number!" && return -1

    [[ "$1" -ne "$2" ]] && [[ "$1" -lt "$2" ]] && return -1

    return 0
}

# Decide which transport (adb or ssh) shall be used to reach a target device.
#   $1 - (mandatory) target device ID (adb serial or IPv4 address)
#   $2 - (mandatory) name of variable receiving the transport: "adb" or "ssh"
# The decision is:
#   - use ssh if the device ID is an IPv4 address;
#   - use ssh if adb is not installed / not accessible;
#   - use adb only if adb is present AND an adb device with the given serial is
#     actually discovered (or no serial was provided but adb sees a device);
#   - fall back to ssh otherwise.
function qimsdk-device-transport() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET_DEVICE_ID=${1}
    local -n OUT_TRANSPORT=${2}

    # An IPv4 address is always reached over ssh.
    qimsdk-is-ipv4 "${TARGET_DEVICE_ID}"                                                        && {
        OUT_TRANSPORT="ssh"
        return 0
    }

    # Without adb we can only use ssh.
    command -v adb > /dev/null 2>&1                                                             || {
        OUT_TRANSPORT="ssh"
        return 0
    }

    # adb is present: check whether the requested device is actually connected.
    local ADB_DEVICES
    ADB_DEVICES=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device"{print $1}')

    [ -z "${TARGET_DEVICE_ID}" ]                                                                && {
        # No serial requested: use adb if it sees at least one device.
        [ -n "${ADB_DEVICES}" ] && OUT_TRANSPORT="adb" || OUT_TRANSPORT="ssh"
        return 0
    }

    grep -qxF "${TARGET_DEVICE_ID}" <<< "${ADB_DEVICES}"                                        && {
        OUT_TRANSPORT="adb"
        return 0
    }

    OUT_TRANSPORT="ssh"
    return 0
}

# Populate the SSH options array used for all ssh / rsync-over-ssh operations.
#   $1 - (mandatory) name of the array variable to populate
# The options are geared towards non-interactive, passwordless (key-based)
# operation that relies on the host's ~/.ssh/config:
#   - BatchMode=yes                 : never prompt for a password / passphrase;
#                                     fail fast instead of blocking automation
#                                     when keys are missing.
#   - StrictHostKeyChecking=accept-new: auto-add unknown host keys on first
#                                     connect without an interactive prompt,
#                                     while still detecting changed keys. This
#                                     preserves ~/.ssh/known_hosts persistence
#                                     (unlike UserKnownHostsFile=/dev/null).
#   - ConnectTimeout                : bound the time spent trying to reach an
#                                     unreachable target.
#   - LogLevel=ERROR                : keep the output clean of banners /
#                                     warnings.
# The host's ~/.ssh/config, ~/.ssh/known_hosts and default host-key checking
# are otherwise left untouched so that per-Host settings (HostName, User,
# IdentityFile, ProxyJump, etc.) are honoured. Callers may still override any
# of these via their own ~/.ssh/config entries.
function qimsdk-ssh-opts() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local -n OUT_SSH_OPTS=${1}

    OUT_SSH_OPTS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10        \
            -o LogLevel=ERROR)

    return 0
}

# Transparent adb wrapper. Behaves like the corresponding adb sub-command when
# adb is available and the device is an adb device, otherwise it transparently
# maps the operation onto ssh (for "shell") and rsync-over-ssh (for "push" and
# "pull"), so that existing callers keep working unchanged.
#   $1 - (mandatory) target device ID (adb serial or IPv4 address)
#   $2 - (mandatory) sub-command: shell | push | pull
#   $@ - (mandatory) sub-command arguments
function qimsdk-cmd() {
    [ $# -lt 2 ]                                                                                && \
        print-red "${FUNCNAME[0]}: expects at least 2 arguments, but got $#!"                   && \
        return -1

    # Reject the call if any of the provided arguments is null or unset: every
    # positional argument (device ID, sub-command and its operands) is mandatory
    # and must be a non-empty string.
    local QIMSDK_ARG_INDEX
    for (( QIMSDK_ARG_INDEX = 1; QIMSDK_ARG_INDEX <= $#; QIMSDK_ARG_INDEX++ )); do
        [ -z "${!QIMSDK_ARG_INDEX+x}" ] || [ -z "${!QIMSDK_ARG_INDEX}" ]                        && {
            print-red "${FUNCNAME[0]}: argument #${QIMSDK_ARG_INDEX} is null or unset !!!"
            return -1
        }
    done

    local TARGET_DEVICE_ID=${1}
    local SUBCMD=${2}
    shift 2

    local TRANSPORT
    qimsdk-device-transport "${TARGET_DEVICE_ID}" TRANSPORT                                     || \
        return -1

    # For the ssh transport, connect using the bare device ID as the ssh target
    # and let the host's ~/.ssh/config fully govern the user, hostname and
    # identity for that Host entry. This is what enables passwordless
    # (key-based) operation without exposing any SSH user / password.
    qimsdk-ssh-opts QIMSDK_SSH_OPTS

    case "${SUBCMD}" in
        shell)
            [ "${TRANSPORT}" = "adb" ]                                                          && {
                [ -n "${TARGET_DEVICE_ID}" ]                                                    && {
                    adb -s "${TARGET_DEVICE_ID}" shell "$@"
                }                                                                               || {
                    adb shell "$@"
                }
            }                                                                                   || {
                ssh "${QIMSDK_SSH_OPTS[@]}" "${TARGET_DEVICE_ID}" "$@"
            }
            ;;
        push)
            # push SRC... DST
            local -a ARGS=("$@")
            local COUNT=${#ARGS[@]}
            local DST=${ARGS[$((COUNT - 1))]}
            local -a SRCS=("${ARGS[@]:0:$((COUNT - 1))}")
            [ "${TRANSPORT}" = "adb" ]                                                          && {
                [ -n "${TARGET_DEVICE_ID}" ]                                                    && {
                    adb -s "${TARGET_DEVICE_ID}" push "${SRCS[@]}" "${DST}"
                }                                                                               || {
                    adb push "${SRCS[@]}" "${DST}"
                }
            }                                                                                   || {
                rsync -aP -e "ssh ${QIMSDK_SSH_OPTS[*]}" "${SRCS[@]}" "${TARGET_DEVICE_ID}:${DST}"
            }
            ;;
        pull)
            # pull SRC... DST
            local -a ARGS=("$@")
            local COUNT=${#ARGS[@]}
            local DST=${ARGS[$((COUNT - 1))]}
            local -a SRCS=("${ARGS[@]:0:$((COUNT - 1))}")
            [ "${TRANSPORT}" = "adb" ]                                                          && {
                [ -n "${TARGET_DEVICE_ID}" ]                                                    && {
                    adb -s "${TARGET_DEVICE_ID}" pull "${SRCS[@]}" "${DST}"
                }                                                                               || {
                    adb pull "${SRCS[@]}" "${DST}"
                }
            }                                                                                   || {
                local SRC
                local -a REMOTE_SRCS=()
                for SRC in "${SRCS[@]}"; do
                    REMOTE_SRCS+=("${TARGET_DEVICE_ID}:${SRC}")
                done
                rsync -aP -e "ssh ${QIMSDK_SSH_OPTS[*]}" "${REMOTE_SRCS[@]}" "${DST}"
            }
            ;;
        *)
            print-red "${FUNCNAME[0]}: unsupported sub-command '${SUBCMD}' !!!"
            return -1
            ;;
    esac
}

# Execute a command on the remote target and faithfully propagate its exit code.
# Works transparently over adb (when available and the device is an adb device)
# or over ssh (for IPv4 targets or when adb is not present).
#   $1 - (optional) device ID (adb serial or IPv4 address)
#   $2 - (mandatory) cmd to be executed
function qimsdk-device-command () {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET_DEVICE_ID=${1}
    local CMD=${2}
    local rc

    # Marker file used to smuggle the remote command's exit code back to the
    # host across the (historically flaky) adb shell channel, whose own exit
    # status does not always reflect the remote command's result. The path is
    # kept in a single variable to avoid brittle literal duplication.
    local REMOTE_RC_FILE="/tmp/qimsdk_rc.$$"

    qimsdk-cmd "${TARGET_DEVICE_ID}" shell "${CMD}; echo \$? > ${REMOTE_RC_FILE}"
    rc=$?
    [ ${rc} -ne 0 ]                                                                             && {
        print-red "Executing command '${CMD}' failed !!!"
        qimsdk-cmd "${TARGET_DEVICE_ID}" shell "rm -f ${REMOTE_RC_FILE}" > /dev/null 2>&1
        return ${rc}
    }

    # Retrieve the captured remote exit code directly, avoiding any host-side
    # temporary file duplication.
    rc=$(qimsdk-cmd "${TARGET_DEVICE_ID}" shell "cat ${REMOTE_RC_FILE}" 2>/dev/null | tr -d '\r\n')
    qimsdk-cmd "${TARGET_DEVICE_ID}" shell "rm -f ${REMOTE_RC_FILE}" > /dev/null 2>&1

    [[ "${rc}" =~ ^[0-9]+$ ]]                                                                   || {
        print-red "Failed to retrieve return code for command '${CMD}' !!!"
        return 1
    }

    [ "${rc}" -ne 0 ]                                                                           && {
        print-red "Command '${CMD}' returned non-zero exit code ${rc} !!!"
        return ${rc}
    }

    return 0
}

# Prepare device after reboot
#   $1 - (optional) device ID
function qimsdk-device-prepare() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TARGET_DEVICE_ID=${1}
    # Privilege-escalation prefix for remote commands. It is intentionally left
    # empty by default: over adb the shell already runs as root, so no 'sudo' is
    # needed (and it may not even exist on the device). It is only set to 'sudo'
    # for the ssh transport below, where commands run as an unprivileged user.
    local TARGET_SU_REQUIRED=""
    local rc

    echo "Waiting for device"

    (
        local rc
        local TRANSPORT
        qimsdk-device-transport "${TARGET_DEVICE_ID}" TRANSPORT                                 || {
            print-red "${FUNCNAME[0]}: error determining connected device transport protocol!"
            return -1
        }

        # The adb root / remount / wait-for-device preparation steps are only
        # meaningful when reaching the target over adb. For ssh targets they
        # are skipped, as the device is expected to be already up and running.
        [ "${TRANSPORT}" = "adb" ]                                                              && {
            [ ! -z ${TARGET_DEVICE_ID} ]                                                        && {
                export ANDROID_SERIAL=${TARGET_DEVICE_ID}
            }

            # Each adb command must be invoked separately: 'wait-for-device' is
            # a state to wait for, whereas 'root' and 'remount' are distinct
            # commands that restart adbd (hence the wait-for-device in between).
            adb wait-for-device
            rc=$?
            [ "${rc}" -ne 0 ]                                                                   && {
                print-red "${FUNCNAME[0]}: adb wait-for-device failed !!!"
                return -1
            }
            adb root
            rc=$?
            [ "${rc}" -ne 0 ]                                                                   && {
                print-red "${FUNCNAME[0]}: adb root failed !!!"
                return -1
            }

            adb wait-for-device
            rc=$?
            [ "${rc}" -ne 0 ]                                                                   && {
                print-red "${FUNCNAME[0]}: adb wait-for-device (post-root) failed !!!"
                return -1
            }
            adb remount
            rc=$?
            [ "${rc}" -ne 0 ]                                                                   && {
                print-red "${FUNCNAME[0]}: adb remount failed !!!"
                return -1
            }

            adb wait-for-device
            rc=$?
            [ "${rc}" -ne 0 ]                                                                   && {
                print-red "${FUNCNAME[0]}: adb wait-for-device (post-remount) failed !!!"
                return -1
            }
        }

        # Only the ssh transport requires privilege escalation: the remote user
        # is unprivileged, so remote commands must be prefixed with 'sudo'. The
        # adb transport keeps TARGET_SU_REQUIRED empty (adb shell is root).
        [ "${TRANSPORT}" = "ssh" ]                                                              && {
            TARGET_SU_REQUIRED="sudo"
        }

        qimsdk-device-command "${TARGET_DEVICE_ID}"                                                \
            "${TARGET_SU_REQUIRED} mount -o remount,rw / > /dev/null"
        rc=$?
        [ "${rc}" -ne 0 ]                                                                       && {
            print-red "file system remount failed !!!"
            return -1
        }

        [ "${TRANSPORT}" = "adb" ] && qimsdk-device-command ${TARGET_DEVICE_ID}                    \
            "mount -o remount,rw /usr > /dev/null"                                              && {
            rc=$?
            [ "${rc}" -ne 0 ]                                                                   && {
                print-red "remount /usr on system failed !!!"
                return -1
            }
        }

        qimsdk-device-command "${TARGET_DEVICE_ID}"                                                \
            "${TARGET_SU_REQUIRED} sh -c '! command -v setenforce || setenforce 0'"
        rc=$?
        [ "${rc}" -ne 0 ]                                                                       && {
            print-red "disable SE Linux failed !!!"
            return -1
        }

        qimsdk-device-command "${TARGET_DEVICE_ID}" "${TARGET_SU_REQUIRED}                         \
            date `date +%m%d%H%M%Y.%S`"
        rc=$?
        [ "${rc}" -ne 0 ]                                                                       && {
            print-red "setting device date failed !!!"
            return -1
        }

        return 0
    )

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Device prepare !!!"
        return ${rc}
    }

    print-green "Device prepared successfully !!!"

    return 0
}

# Get container and image from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give container name as argument
#   $3 - (mandatory) give image name as argument
function qimsdk-get-container-and-image-name() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CONTAINER_NAME=${2}
    local -n OUT_QIMSDK_IMAGE_NAME=${3}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    local QIMSDK_ADDITIONAL_TAG=$(
        echo ${JSON_CONTENT} |  jq '.Additional_tag_container' | tr -d '"'
    )

    [ ! -z "${QIMSDK_ADDITIONAL_TAG}" ] && {
        QIMSDK_ADDITIONAL_TAG="-${QIMSDK_ADDITIONAL_TAG}"
    }

    OUT_QIMSDK_CONTAINER_NAME="qimsdk${QIMSDK_ADDITIONAL_TAG}"

    local ADDITIONAL_TAG_IMAGE=$(echo ${JSON_CONTENT} |  jq '.Additional_tag_image' | tr -d '"')

    [ ! -z "${ADDITIONAL_TAG_IMAGE}" ] && {
        ADDITIONAL_TAG_IMAGE="-${ADDITIONAL_TAG_IMAGE}"
    }

    OUT_QIMSDK_IMAGE_NAME="qimsdk${ADDITIONAL_TAG_IMAGE}"

    return 0
}

# Get remote sync destination from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Docker_image_path as argument
function qimsdk-get-docker-image-path() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_DOCKER_IMAGE_PATH=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_DOCKER_IMAGE_PATH=$(echo ${JSON_CONTENT} |  jq '.Docker_image_path' | tr -d '"')

    qimsdk-expand-tilde OUT_DOCKER_IMAGE_PATH

    [ -z "${OUT_DOCKER_IMAGE_PATH}" ] && {
        print-red "Docker_image_path attribute in config.json is not set !!!"
        return -1
    }

    return 0
}

# Get qimsdk components commit ID or tag
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give camera service commit ID or tag as argument
#   $3 - (mandatory) give gst plugins commit ID or tag as argument
#   $4 - (mandatory) give solutions microservices commit ID or tag as argument
function qimsdk-get-components-tag() {
    local QIMSDK_ARG_COUNT_EXPECTED=4
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_CAMERA_SERVICE_TAG=${2}
    local -n OUT_QIMSDK_GST_PLUGINS_TAG=${3}
    local -n OUT_QIMSDK_SOLUTIONS_MICROSERVICES_TAG=${4}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_CAMERA_SERVICE_TAG=$(
        jq -er '.camera_service_git_tag // ""' <<< "${JSON_CONTENT}" 2>/dev/null || echo ""
    )

    OUT_QIMSDK_GST_PLUGINS_TAG=$(
        jq -er '.IM_SDK_Source_git_tag // ""' <<< "${JSON_CONTENT}" 2>/dev/null || echo ""
    )

    OUT_QIMSDK_SOLUTIONS_MICROSERVICES_TAG=$(
        jq -er '.solutions_microservices_Source_git_tag // ""' <<< "${JSON_CONTENT}"               \
                2>/dev/null || echo ""
    )

    return 0
}

# Validate that a string is a dotted-quad IPv4 address (XXX.XXX.XXX.XXX) where
# every one of the four octets is a decimal number within the 0-255 range.
#   $1 - (mandatory) string to validate
# Returns 0 when the argument is a valid IPv4 address, non-zero otherwise.
function qimsdk-is-ipv4() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local CANDIDATE=${1}

    # Must be exactly four dot-separated groups of 1 to 3 decimal digits.
    [[ "${CANDIDATE}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]                    || \
        return 1

    # Validate the numeric range of every octet: each must be within 0-255.
    local -a OCTETS
    IFS='.' read -r -a OCTETS <<< "${CANDIDATE}"

    local OCTET
    for OCTET in "${OCTETS[@]}"; do
        # Force base-10 interpretation via 10#: a leading zero would otherwise
        # be treated as octal in arithmetic context (e.g. "08"/"09" would raise
        # an "invalid octal number" error). The regex above already guarantees
        # OCTET is a non-empty 1-3 digit string, so no emptiness / lower-bound
        # checks are required here.
        (( 10#${OCTET} <= 255 )) || return 1
    done

    return 0
}

# Validate that a string looks like an adb device serial number. adb serials
# are non-empty tokens without whitespace that are NOT dotted-quad IPv4
# addresses (IPv4 addresses are always handled by the SSH transport).
#   $1 - (mandatory) string to validate
# Returns 0 when the argument looks like an adb serial, non-zero otherwise.
function qimsdk-is-adb-serial() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local CANDIDATE=${1}

    [ -z "${CANDIDATE}" ]                                                                       && {
        print-red "${FUNCNAME[0]}: empty or unset adb serial argument value!"
        return 1
    }
    qimsdk-is-ipv4 "${CANDIDATE}"                                                               && {
        print-red "${FUNCNAME[0]}: provided adb serial argument value matches an IPv4 address string!"
        return 1
    }
    [[ "${CANDIDATE}" =~ [[:space:]] ]]                                                         && {
        print-red "${FUNCNAME[0]}: provdied adb serial argument value containes invalid sybmols!"
        return 1
    }

    return 0
}

# Get Device ID from json
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) give Device ID as argument
function qimsdk-get-device-id() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_TARGET_DEVICE_ID=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ] && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_TARGET_DEVICE_ID=$(echo ${JSON_CONTENT} |  jq '.Target_device_ID' | tr -d '"')

    [ -z "${OUT_TARGET_DEVICE_ID}" ] && {
        print-red "Target_device_ID attribute in config.json is not set !!!"
        return -1
    }

    # The device ID may be either an adb device serial number, or a remote
    # device IPv4 address in dotted-quad (XXX.XXX.XXX.XXX) form. Validate that
    # it matches one of these two accepted patterns.
    qimsdk-is-adb-serial "${OUT_TARGET_DEVICE_ID}"                                              || \
            qimsdk-is-ipv4 "${OUT_TARGET_DEVICE_ID}"                                            || {
        print-red "Target_device_ID '${OUT_TARGET_DEVICE_ID}' is neither a valid adb serial"
        print-red "number nor a valid IPv4 address (XXX.XXX.XXX.XXX) !!!"
        return -1
    }

    return 0
}

# Remote Sync Wrapper
# Sync from host to remote and clean-up if success
#   $1 - (mandatory) SRC: source to sync
#   $2 - (mandatory) DST: destination where to sync
function qimsdk-sync-to-remote-and-clean() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local SRC=${1}
    local DST=${2}

    [[ -d ${DST} || -f ${DST} ]] && {
        return 0
    }

    rsync -aP ${SRC} ${DST}

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: rsync -aP ${SRC} ${DST}"
        return ${rc}
    }

    rm -f ${SRC}

    rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: rm ${SRC}"
        return ${rc}
    }

    return 0
}

# Remove
# Remove argument if its located in tmp of file system
#   $1 - (mandatory) TEMP: file or dir to remove
function qimsdk-remove-if-temp() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local TEMP=${1}

    [ -z ${TEMP} ] && {
        return 0
    }

    [[ "${TEMP}" == /tmp/* ]] && {
        rm -rf ${TEMP}
    }

    return 0
}

# Generate Docker compose CDI yaml file
#   $1 - (mandatory) path to Docker compose yaml
#   $2 - (mandatory) container name from user's config json
#   $3 - (mandatory) image name from user's config json
function qimsdk-generate-docker-compose-yaml() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_DOCKER_COMPOSE_YAML=${1}
    local CONTAINER_NAME=${2}
    local IMAGE_NAME=${3}
    local MODEL_ROOT="/etc"
    declare -a QIMSDK_USER_CONTENTS_DIRS_ARRAY=("media" "models" "labels" "configs")

    yq -n ".name=\"${IMAGE_NAME}\"" > ${PATH_TO_DOCKER_COMPOSE_YAML}                            && \
            yq -i ".services.qimsdk.image=\"${IMAGE_NAME}\"" ${PATH_TO_DOCKER_COMPOSE_YAML}     && \
            yq -i ".services.qimsdk.container_name\"${CONTAINER_NAME}\""                           \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i ".services.qimsdk.hostname=\"${CONTAINER_NAME}\""                                \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i '.services.qimsdk.stdin_open=true' ${PATH_TO_DOCKER_COMPOSE_YAML}             && \
            yq -i '.services.qimsdk.tty=true' ${PATH_TO_DOCKER_COMPOSE_YAML}                    && \
            yq -i '.services.qimsdk.restart="always"' ${PATH_TO_DOCKER_COMPOSE_YAML}            && \
            yq -i '.services.qimsdk.network_mode="host"' ${PATH_TO_DOCKER_COMPOSE_YAML}         && \
            for I in ${QIMSDK_USER_CONTENTS_DIRS_ARRAY[@]}; do
                yq -i ".services.qimsdk.volumes += [\"${MODEL_ROOT}/${I}:${MODEL_ROOT}/${I}\"]"    \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}
            done                                                                                && \
            yq -i '.services.qimsdk.env_file=["/etc/docker/env/qimsdk.env"]'                       \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i '.services.qimsdk.deploy.resources.reservations.devices[0].driver = "cdi"'       \
                    ${PATH_TO_DOCKER_COMPOSE_YAML}                                              && \
            yq -i '.services.qimsdk.deploy.resources.reservations.devices[0].device_ids[0] =
                    "qualcomm.com/device=cdi-hw-acc"' ${PATH_TO_DOCKER_COMPOSE_YAML}            && \
            yq -i '.services.qimsdk.deploy.resources.reservations.devices[0].capabilities =
                    ["hw-acc"]' "${PATH_TO_DOCKER_COMPOSE_YAML}"                                || {
        print-red "Failed to generate Docker compose CDI yaml file !!!"
        rm -rf  ${PATH_TO_DOCKER_COMPOSE_YAML}
        return -1
    }

    return 0
}

# Generate docker run cdi cmd in shell file
#   $1 - (mandatory) remote path
#   $2 - (mandatory) container name from user's config json
#   $3 - (mandatory) image name from user's config json
function qimsdk-generate-docker-run-cmd() {
    local QIMSDK_ARG_COUNT_EXPECTED=3
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local RESULT=${1}
    local CONTAINER_NAME=${2}
    local IMAGE_NAME=${3}
    local MODEL_ROOT="/etc"

    echo "docker run -it -d --net host --env-file /etc/docker/env/qimsdk.env `
            `--device qualcomm.com/device=qimsdk -h ${CONTAINER_NAME} `
            `-v ${MODEL_ROOT}/media:${MODEL_ROOT}/media `
            `-v ${MODEL_ROOT}/models:${MODEL_ROOT}/models `
            `-v ${MODEL_ROOT}/labels:${MODEL_ROOT}/labels `
            `-v ${MODEL_ROOT}/configs:${MODEL_ROOT}/configs `
            `--name ${CONTAINER_NAME} ${IMAGE_NAME}" > ${RESULT}

    local rc=$?
    [ ${rc} -ne 0 ] && {
        print-red "FAILED: Failed to construct Docker run CDI cmd !!!"
        return ${rc}
    }

    return 0
}

# Get map of host to dbg container to mount src dirs
#   $1 - (mandatory) path to target config json
#   $2 - (mandatory) output map
function qimsdk-get-map-for-dbg-container() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_DEV_MAP=${2}

    local JSON_CONTENT=$(
        cat ${PATH_TO_CONFIG_JSON}
    )

    local DOCKER_IMAGE_PATH="/mnt/work/dev_artifacts"
    local HOST_DOCKER_IMAGE_PATH=""

    qimsdk-get-docker-image-path ${PATH_TO_CONFIG_JSON} HOST_DOCKER_IMAGE_PATH

    local MAP_SOURCES_TO_DEV_CONTAINER=$(
        echo ${JSON_CONTENT} |  jq '.MAP_sources_to_dev_container' | tr -d '"'
    )

    declare -a DEV_MAP_ARR=""

    [[ "${MAP_SOURCES_TO_DEV_CONTAINER}" =~ ^(TRUE|ENABLE|ENABLED)$ ]]                          && {

        local GST_SRC_DIR=$(
            echo ${JSON_CONTENT} |  jq '.IM_SDK_Source_Dir' | tr -d '"'
        )

        qimsdk-expand-tilde GST_SRC_DIR

        [[ -z ${GST_SRC_DIR} ]]                                                                 && {
            return 0
        }

        [ -d ${GST_SRC_DIR} ] && {
            DEV_MAP_ARR+="-v ${GST_SRC_DIR}:/mnt/work/src/gst-plugins-imsdk "
        }

    }

    DEV_MAP_ARR+="-v ${HOST_DOCKER_IMAGE_PATH}:${DOCKER_IMAGE_PATH} "

    OUT_DEV_MAP=${DEV_MAP_ARR}

    return 0
}

# expand tilde to real path
#   $1 - (mandatory) path
function qimsdk-expand-tilde() {
    local QIMSDK_ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local -n INPUT_PATH=${1}

    [[ "$INPUT_PATH" == ~* ]] && {
        # Swap "~" with ${HOME} variable
        INPUT_PATH="${INPUT_PATH/#\~/${HOME}}"
    }
}

# Argument unsigned 10-digit number checker.
#   $1 - (mandatory) number argument to be checked
function qimsdk-is-arg-number() {
    local ARG_COUNT_EXPECTED=1
    ! qimsdk-arg-count-check $# ${ARG_COUNT_EXPECTED}                                           && \
        print-red "${FUNCNAME[0]}: expects ${ARG_COUNT_EXPECTED} arguments, but got $#!"        && \
        return -1

    local NUMBER_ARG=${1}

    ! [[ "${NUMBER_ARG}" =~ ^[0-9]{1,10}$ ]]                                                    && \
        return -1

    return 0
}

# Get maximum number of build threads from json
#   $1 - (mandatory) path to target config json
#   $2 - (output) give number of max build threads, if set
function qimsdk-get-max-build-jobs() {
    local QIMSDK_ARG_COUNT_EXPECTED=2
    ! qimsdk-arg-count-check $# ${QIMSDK_ARG_COUNT_EXPECTED}                                    && \
        print-red "${FUNCNAME[0]}: expects ${QIMSDK_ARG_COUNT_EXPECTED} arguments, but got $#!" && \
        return -1

    local PATH_TO_CONFIG_JSON=${1}
    local -n OUT_QIMSDK_MAX_BUILD_JOBS=${2}

    [ ! -f "${PATH_TO_CONFIG_JSON}" ]                                                           && {
        print-red "Path to target configuration json must be provided as first argument !!!"
        return -1
    }

    local JSON_CONTENT=$(cat ${PATH_TO_CONFIG_JSON})

    OUT_QIMSDK_MAX_BUILD_JOBS=$(echo ${JSON_CONTENT} |                                             \
            jq '.MAX_build_cpu_threads' | tr -d '"')

    [[ -n "${OUT_QIMSDK_MAX_BUILD_JOBS}" ]]                                                     && \
                    qimsdk-is-arg-number "${OUT_QIMSDK_MAX_BUILD_JOBS}"                         && {
        [[ "${OUT_QIMSDK_MAX_BUILD_JOBS}" -le 0 ]]                                              || \
                [[ "${OUT_QIMSDK_MAX_BUILD_JOBS}" -gt $(nproc) ]]                               && {
            print-red "Max build threads argument value set: ${OUT_QIMSDK_MAX_BUILD_JOBS}"
            print-red "Max build threads argument value must be within: 0 - $(nproc)! Exit!"
            return -1
        }                                                                                       || {
            OUT_QIMSDK_MAX_BUILD_JOBS="${OUT_QIMSDK_MAX_BUILD_JOBS#+}"
        }
    }                                                                                           || {
        OUT_QIMSDK_MAX_BUILD_JOBS=$(nproc)
    }

    return 0
}
