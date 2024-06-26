#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
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

# Source all scripts
for f in ${QIMSDK_SCRIPTS}/*.sh; do
    [ "${f}" == "${QIMSDK_SCRIPTS}/env_setup.sh" ]                                              || \
        source ${f}
done
$@
