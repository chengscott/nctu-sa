#!/bin/sh
ls -ARl -D '' | grep '^[d-]' | cut -d' ' -f1,7- | cut -c1,11- | sort -nrk 2 | awk 'BEGIN {top=1;dn=0;fn=0;ts=0} {
  if ($1 == "-") {
    if (top < 6) {
      print top":"$2, $3
      top = top + 1
    }
    fn = fn + 1
    ts = ts + $2
  } else {
    dn = dn + 1
  }
} END {
  print "Dir num:", dn
  print "File num:", fn
  print "Total:", ts
}'
