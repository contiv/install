#!/usr/bin/env python

import json
import requests
import sys

DEFAULT_VERSION = "1.0.0"

HTTP_OK = 200

# Try to get the latest release version
r = requests.get("https://api.github.com/repos/contiv/install/releases/latest")
if r.status_code != HTTP_OK:
   # Get all the releases (include pre-releases) and pick the first of them
   r = requests.get("https://api.github.com/repos/contiv/install/releases")
   if r.status_code != HTTP_OK:
      # Return a known version
      print DEFAULT_VERSION
      sys.exit(1)

   try:
      releases = json.loads(r.content)
      print releases[0]['name']
   except:
      print DEFAULT_VERSION
      sys.exit(1)
try:
   releases = json.loads(r.content)
   print releases['name']
except:
    print DEFAULT_VERSION
    sys.exit(1)
