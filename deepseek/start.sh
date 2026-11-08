#!/bin/sh
set -eu
umask 077
bind_ip=$(hostname -i | awk '{print $1}')
exec dsh web --patch /etc/dsh-container.patch.yml --host "$bind_ip" --port 3080 --public-url http://127.0.0.1:3080 --no-open

