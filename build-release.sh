#!/bin/sh
set -e

# builds for each OS and then uploads to a fresh github release.
# make an access token first here: https://github.com/settings/tokens
# and save it somewhere.
#
# must have go compiler boot strapped for all OS for go <= 1.4 -- try this:
#   % git clone git://github.com/davecheney/golang-crosscompile.git
#   % source golang-crosscompile/crosscompile.bash
#   % go-crosscompile-build-all
#
# also must have python, curl installed

old=$(grep -E "release.*=.*'.*'" install.sh | grep -Eo "'.*'")

# TODO taking ideas for automating this, can we make a bot+token and stick it in CircleCI?
echo -n "GitHub username: "
read name
echo -n "Access Token (https://github.com/settings/tokens): "
read tok
echo -n "New Version (current: $old): "
read version

url='https://api.github.com/repos/iron-io/ironcli/releases'

output=$(curl -s -u $name:$tok -d "{\"tag_name\": \"$version\", \"name\": \"$version\"}" $url)
upload_url=$(echo "$output" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["upload_url"]' | sed -E "s/\{.*//")
html_url=$(echo "$output" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["html_url"]')

sed -Ei "s/release.*=.*'.*'/release='$version'/"        install.sh
sed -Ei "s/Version.*=.*\".*\"/Version = \"$version\"/"  main.go

# NOTE: do the builds after the version has been bumped in main.go
echo "uploading exe..."
GOOS=windows  GOARCH=amd64 go build -o bin/ironcli.exe
curl --progress-bar --data-binary "@bin/ironcli.exe"    -H "Content-Type: application/octet-stream" -u $name:$tok $upload_url\?name\=ironcli.exe >/dev/null
echo "uploading elf..."
GOOS=linux    GOARCH=amd64 go build -o bin/ironcli_linux
curl --progress-bar --data-binary "@bin/ironcli_linux"  -H "Content-Type: application/octet-stream" -u $name:$tok $upload_url\?name\=ironcli_linux >/dev/null
echo "uploading mach-o..."
GOOS=darwin   GOARCH=amd64 go build -o bin/ironcli_mac
curl --progress-bar --data-binary "@bin/ironcli_mac"    -H "Content-Type: application/octet-stream" -u $name:$tok $upload_url\?name\=ironcli_mac >/dev/null

git add -u
git ci -m "$version"
git push origin master

echo "Done! Go edit the description: $html_url"
