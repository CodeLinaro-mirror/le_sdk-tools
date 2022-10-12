#!/bin/bash

# Copyright (c) 2022-2023 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

function print-red()
{
    tput setaf 1 && echo $1 && tput sgr0
}

function print-green()
{
    tput setaf 2 && echo $1 && tput sgr0
}

function print-blue()
{
    tput setaf 4 && echo $1 && tput sgr0
}
