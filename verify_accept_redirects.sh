#!/bin/bash
#
# Report if redirects are accepted
# Author: Andreas Karis <akaris@redhat.com>
#

proto=ipv4
interfaces=$(sysctl -a 2>/dev/null | egrep "net\.${proto}.*accept_redirects" | awk  -F '.' '{print $4}' | grep -v all)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

for interface in $interfaces; do
  accept_redirect="no"
  if [ $(sysctl -n net.${proto}.conf.${interface}.accept_redirects) -eq 1 ] && [ $(sysctl -n net.${proto}.conf.all.accept_redirects) -eq 1 ]; then
    printf "${RED}Both all.accept_redirects and ${interface}.accept_redirects are set ...${NC}\n"
    accept_redirect="yes"
  elif [ $(sysctl -n net.${proto}.conf.${interface}.accept_redirects) -eq 1 ] || [ $(sysctl -n net.${proto}.conf.all.accept_redirects) -eq 1 ]; then
      printf "${YELLOW}Either ${interface}.accept_redirects or all.accept_redirects is set ...${NC}\n"
    if [ $(sysctl -n net.${proto}.conf.${interface}.forwarding) -eq 0 ]; then
       printf "${RED}Forwarding on this interface is off, hence we will accept redirects${NC}\n"
      accept_redirect="yes"
    fi 
  fi

  echo "Interface $interface, accept_redirect is enabled? " 
  if [ "$accept_redirect" == "yes" ]; then
    printf "${RED}This interface accepts redirects${NC}\n"
  else
    printf "${GREEN}This interface does not accept redirects${NC}\n"
  fi
done
