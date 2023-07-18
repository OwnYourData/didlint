import pytest
import os
import sys
import glob
import requests
import subprocess
from pathlib import Path

# $ URL="http://localhost:3000" pytest test_ddo.py
url = os.getenv('URL') or "https://didlint.ownyourdata.eu"

# structure
# 00 - admin
# 01 - DIDs
# 02 - DID Documents
# 03 - JSON-LD context handling

# 02 validate DID Documents
cwd = os.getcwd()
@pytest.mark.parametrize('input',  glob.glob(cwd+'/02_input/*.json'))
def test_01_simple(fp, input):
    print(input)
    fp.allow_unregistered(True)
    with open(input) as f:
        doc = f.read()
    with open(input.replace("_input/", "_output/")) as f:
        result = f.read()
    command = "echo '"  + doc + "' | curl -H 'Content-Type: application/json' -d @- -X POST " + url + "/api/validate"
    process = subprocess.run(command, shell=True, capture_output=True, text=True)
    assert process.returncode == 0
    if len(result) > 0:
        assert process.stdout.strip() == result.strip()
