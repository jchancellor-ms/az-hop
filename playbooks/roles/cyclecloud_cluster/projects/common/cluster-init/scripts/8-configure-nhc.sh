#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../files/azhop-helpers.sh" 
read_os

$SCRIPT_DIR/../files/$os_release/init_nhc.sh

NHC_CONFIG_FILE="/etc/nhc/nhc.conf"
VM_SIZE=$(curl -s --noproxy "*" -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2019-08-15" | jq -r '.vmSize' | tr '[:upper:]' '[:lower:]' | sed 's/standard_//')

NHC_CONFIG_EXTRA="$SCRIPT_DIR/../files/nhc/nhc_${VM_SIZE}.conf"

# Use common config for all compute nodes
if [ -e $NHC_CONFIG_FILE ]; then
    rm -f ${NHC_CONFIG_FILE}.bak
    mv $NHC_CONFIG_FILE ${NHC_CONFIG_FILE}.bak
fi
cp -fv $SCRIPT_DIR/../files/nhc/nhc_common.conf $NHC_CONFIG_FILE

# Append VM size specific config if exists
if [ -e $NHC_CONFIG_EXTRA  ]; then
    cat $NHC_CONFIG_EXTRA >> $NHC_CONFIG_FILE
fi