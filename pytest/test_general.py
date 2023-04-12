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

# 00 - Admin
def test_access():
    response = requests.get(url)
    assert response.status_code == 200
    response = requests.get(url + '/version')
    assert response.status_code == 200
    response = requests.get(url + '/validate?did=did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1')
    assert response.status_code == 200
