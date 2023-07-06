#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Update ssh config with key exchange method if it is missing
[ -f ~/.ssh/config ] && \
    grep -zq "KexAlgorithms +diffie-hellman-group1-sha1" ~/.ssh/config ||      \
        echo -e "\n\nHost *\n\tKexAlgorithms +diffie-hellman-group1-sha1\n" >> ~/.ssh/config

# Setup helper scripts
[ -f ${QIMSDK_SCRIPTS}/env_setup.sh ] && source ${QIMSDK_SCRIPTS}/env_setup.sh

# Raise priority of installed git packet over esdk git
PATH=~/bin:$PATH
[ ! -f ~/bin/git ] && mkdir -p ~/bin/ && ln -s /usr/bin/git ~/bin/git
