FROM contiv_install_base
MAINTAINER contiv

# TODO: Replace this with a specific contiv/ansible release version
# Get the ansible scripts required for both netplugin docker & for k8s contrib
RUN git clone http://github.com/neelimamukiri/ansible -b local_images

RUN wget -c https://raw.githubusercontent.com/neelimamukiri/demo/master/net/extras/genInventoryFile.py
RUN chmod +x genInventoryFile.py

# Add the install scripts
ADD install install

RUN chmod +x install/ansible/install.sh
RUN chmod +x install/ansible/uninstall.sh
ADD generate-certificate.sh .
RUN chmod +x generate-certificate.sh
