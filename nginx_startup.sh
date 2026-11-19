#!/bin/bash

echo "# This file is auto-generated everything time, based on the container's /etc/resolv.conf file."> /etc/nginx/resolver.conf
echo "resolver $(cat /etc/resolv.conf | grep "nameserver" | awk 'NR==1{print $2}') valid=30s;" >> /etc/nginx/resolver.conf

/sbin/nginx "$@"