#!/bin/bash

# Copyright (c) 2024 Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# Save artifacts to URL provided in config json file.
function qimsdk-dev-save-artifacts() {

    pushd ${QIMSDK_BASE_DIR}/deploy > /dev/null
        tar cf qimsdk_dev_artifacts.tar ./*                                                     && \
            rsync -aP qimsdk_dev_artifacts.tar ${URL}                                           || \
            {
                echo "rsync -a qimsdk_dev_artifacts.tar ${URL} failed !!!"
                popd > /dev/null
                return -1
            }
        rm -f qimsdk_dev_artifacts.tar
    popd  > /dev/null

    echo "Dev artifacts saved to ${URL}"
}

print-blue "qimsdk-dev-save-artifacts"
echo "    Send built binaries to URL specified in config json file"
