#!/usr/local/bin/python

import json
import requests

HTTP_OK = 200
# Try to get the latest release version
r = requests.get("https://api.github.com/repos/contiv/install/releases/latest")
if r.status_code != HTTP_OK:
   # Get all the releases (include pre-releases) and pick the first of them
   r = requests.get("https://api.github.com/repos/contiv/install/releases")
   if r.status_code != HTTP_OK:
      # Return a known version
      print "1.0.0-beta.3"
      sys.exit(1)
try:
   releases = json.loads(r.content)
   print releases[0]['name']
except:
    print "1.0.0-beta.3"
    sys.exit(1)
