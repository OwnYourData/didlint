import pytest
import os
import sys
import glob
import requests
import subprocess
from pathlib import Path

url = os.getenv('URL') or "https://didlint.ownyourdata.eu"

# structure
# 00 - admin
# 01 - DIDs
# 02 - DID Documents

# 01 - validate DIDs
cwd = os.getcwd()
# doc: https://pypi.org/project/pytest-subprocess/
@pytest.mark.parametrize('input',  glob.glob(cwd+'/01_input/*.doc'))
def test_01_simple(fp, input):
    fp.allow_unregistered(True)
    with open(input) as f:
        did = f.read()
    with open(input.replace("_input/", "_output/")) as f:
        result = f.read()
    command = "curl " + url + "/api/validate/" + did
    process = subprocess.run(command, shell=True, capture_output=True, text=True)
    assert process.returncode == 0
    if len(result) > 0:
        assert process.stdout.strip() == result.strip()
