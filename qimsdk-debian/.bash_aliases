#!/bin/bash

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Switch context to qimsdk user on every started shell
[ "$(id -u)" = "0" ] && exec gosu qimsdk bash
