#!/usr/bin/python3

# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

from inspect import currentframe


def print_linenumber():
    cf = currentframe()
    print(cf.f_back.f_lineno)
