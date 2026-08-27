#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Some more ls aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Enable bash completion in interactive shells
[ -f /etc/bash_completion ] && . /etc/bash_completion

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

    ! [[ "$1" =~ ^[0-9]{1,2}$ ]] && \
        print-red "${FUNCNAME[0]}: first argument must be a non-signed number!" && return -1

    ! [[ "$2" =~ ^[0-9]{1,2}$ ]] && \
        print-red "${FUNCNAME[0]}: second argument must be a non-signed number!" && return -1

    [[ "$1" -ne "$2" ]] && [[ "$1" -lt "$2" ]] && return -1

    return 0
}

# Source all scripts
for f in ${QIMSDK_SCRIPTS}/*.sh; do
    [ "${f}" == "${QIMSDK_SCRIPTS}/env_setup.sh" ] || source ${f}
done
$@
