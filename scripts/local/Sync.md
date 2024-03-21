# Python Sync wheel

### Install necessary pip3 packages
```bash
pip3 install --upgrade pip setuptools wheel
```

### Generate python package (.whl)
```bash
cd </path/to/local/scripts/>
python3 setup_qimsdk_sync.py bdist_wheel
```

This will generate several directories,
where the package (.whl) will be in "dist" directory

### Install qimsdk_sync via pip3
```bash
cd ./dist/

pip3 install qimsdk_sync-1.0-py3-none-any.whl
```

The completion of the above command successfully means that the package has been
successfully installed on the host machine,
and it can be easily invoked by passing the path to the archives and a "command"
The above mentioned "command" can be "install" or "remove"

### For Windows PowerShell

There will be the following warning:
WARNING: The script qimsdk_sync.exe is installed in
    'C:\Users\CurrentUser\AppData\Local\Packages\PythonSoftwareFoundation.Python.......\LocalCache\local-packages\Python3..\Scripts'
    is not on PATH.

So make it a part of PATH.

```PowerShell
$env:PATH += ";C:\Users\<CurrentUser>\AppData\Local\Packages\PythonSoftwareFoundation.Python.......\LocalCache\local-packages\Python3..\Scripts"
```

### Install packages to the device
```bash
qimsdk_sync </path/to/qimsdk/packages/dir/> install
```

### Remove packages from the device
```bash
qimsdk_sync </path/to/qimsdk/packages/dir/> remove
```

### Uninstall qimsdk_sync via pip3
```bash
pip3 uninstall qimsdk_sync
```

# Note: All python scripts tested on python versions: 3.6.9 and 3.12.1
