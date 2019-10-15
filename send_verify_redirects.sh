#!/bin/bash
#
# Report if redirects are sent
# Author: Andreas Karis <akaris@redhat.com>
#

proto=ipv4
interfaces=$(sysctl -a 2>/dev/null | egrep "net\.${proto}.*send_redirects" | awk  -F '.' '{print $4}' | grep -v all)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

for interface in $interfaces; do
  send_redirect="no"
  if [ $(sysctl -n net.${proto}.conf.${interface}.send_redirects) -eq 1 ] || [ $(sysctl -n net.${proto}.conf.all.send_redirects) -eq 1 ]; then
      printf "${YELLOW}Either ${interface}.send_redirects or all.send_redirects is set ...${NC}\n"
    if [ $(sysctl -n net.${proto}.conf.${interface}.forwarding) -eq 1 ] ; then
       printf "${RED}Forwarding on this interface is on, hence we will send redirects${NC}\n"
       send_redirect="yes"
    fi 
  fi

  echo "Interface $interface, send_redirect is enabled? " 
  if [ "$send_redirect" == "yes" ]; then
    printf "${RED}This interface sends redirects\n"
    sysctl net.${proto}.conf.${interface}.send_redirects
    sysctl net.${proto}.conf.all.send_redirects
    sysctl net.${proto}.conf.${interface}.forwarding
    printf "${NC}"
  else
    printf "${GREEN}This interface does not send redirects${NC}\n"
  fi
done
