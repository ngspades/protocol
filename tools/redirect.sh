#!/bin/sh
# Redirect pages for the example READMEs, which the old Jekyll site served as
# /examples/c/README.html and /examples/godot/README.html.
set -e
site=$1
for lang in c godot; do
  mkdir -p "$site/examples/$lang"
  url="https://github.com/ngspades/protocol/tree/main/examples/$lang"
  for f in README.html index.html; do
    cat > "$site/examples/$lang/$f" <<HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Redirecting</title>
<meta http-equiv="refresh" content="0; url=$url"><link rel="canonical" href="$url"></head>
<body><p>The $lang examples are in the repository: <a href="$url">$url</a>.</p></body></html>
HTML
  done
done
