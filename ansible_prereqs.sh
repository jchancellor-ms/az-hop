#!/bin/bash
set -e

if [[ `pip3 list pypsrp` == *"pypsrp"* ]]; then 
  echo pypsrp is already installed 
else
  pip3 install pypsrp
fi
if [[ `pip3 list PySocks` == *"PySocks"* ]]; then 
  echo PySocks is already installed 
else
  pip3 install PySocks
fi
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install community.windows
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general

# This is to fix an issue when using delegate_to
if [ -f /usr/bin/python3 ] && [ ! -f /usr/bin/python ]; then 
  sudo ln --symbolic /usr/bin/python3 /usr/bin/python; 
fi
