#!/usr/bin/env bash
set -euo pipefail

awk '
/ 500 / {c500++}
/yoko/ && /GET \/rrhh/ && / 200 / {yoko++}
/"\/"/ {root++}
!/ 5[0-9][0-9] / {no5xx++}
{gsub(/ 503 /," 500 "); if ($0 ~ / 500 /) new500++}
END {
print "500:",c500
print "yoko GET /rrhh 200:",yoko
print "requests to /:",root
print "without 5xx:",no5xx
print "500 after replace:",new500
}' sample.log
