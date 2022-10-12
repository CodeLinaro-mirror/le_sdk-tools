#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Update ssh config with key exchange method if it is missing
[ -f ~/.ssh/config ] && \
    grep -zq "KexAlgorithms +diffie-hellman-group1-sha1" ~/.ssh/config ||      \
        echo -e "\n\nHost *\n\tKexAlgorithms +diffie-hellman-group1-sha1\n" >> ~/.ssh/config

# Setup helper scripts
[ -f ${QIMSDK_SCRIPTS}/env_setup.sh ] && source ${QIMSDK_SCRIPTS}/env_setup.sh

# Fix git autocomplete
function qimsdk-fix-git-autocomplete() {
    [ ! -f ${QIMSDK_WORK_FOLDER}/git-completion.bash ] && {
        local GIT_VERSION=`git --version | rev | cut -d ' ' -f 1 | rev`
        mkdir -p ${QIMSDK_WORK_FOLDER}
        wget https://raw.githubusercontent.com/git/git/v${GIT_VERSION}/contrib/completion/git-completion.bash -O ${QIMSDK_WORK_FOLDER}/git-completion.bash
    }

    source ${QIMSDK_WORK_FOLDER}/git-completion.bash
}
qimsdk-fix-git-autocomplete
