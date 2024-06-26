#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Some more ls aliases
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Enable bash completion in interactive shells
[ -f /etc/bash_completion ] && . /etc/bash_completion

# Setup helper scripts
[ -f ${QIMSDK_SCRIPTS}/env_setup.sh ] && source ${QIMSDK_SCRIPTS}/env_setup.sh
