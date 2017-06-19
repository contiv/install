#!/usr/bin/env python

import json
import requests
import sys

HTTP_OK = 200

# Try to get the latest release version
r = requests.get("https://api.github.com/repos/contiv/install/releases/latest")
if r.status_code != HTTP_OK:
   print >> sys.stderr, "failed to get latest release, status code: %d" % r.status_code
   sys.exit(1)
else:
   releases = json.loads(r.content)
   print releases['name']
