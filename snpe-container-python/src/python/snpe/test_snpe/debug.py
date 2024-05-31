#!/usr/bin/python3

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

from inspect import currentframe


def print_linenumber():
    cf = currentframe()
    print(cf.f_back.f_lineno)
