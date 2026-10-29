#!/bin/sh
# Build the .deb files of one package inside a Debian testing container.
#
#   sh build.sh <name> <git url> <commit> [version]
#
# Results go to out/. Any .deb files in deps/ are installed first.
set -eu

name=$1
url=$2
commit=$3
version=${4:-}
top=$PWD

export DEBIAN_FRONTEND=noninteractive
export DEB_BUILD_OPTIONS="noautodbgsym nocheck"

# Some justfiles write this into the build, as the Pop!_OS build does.
export SOURCE_GIT_HASH=$commit

apt-get update -q
apt-get install -y -q --no-install-recommends ca-certificates git git-lfs build-essential

if ls deps/*.deb >/dev/null 2>&1; then
	apt-get install -y -q ./deps/*.deb
fi

mkdir -p "src/$name" out
cd "src/$name"
git init -q
if git config --local --get remote.origin.url >/dev/null; then
	git remote set-url origin "$url"
else
	git remote add origin "$url"
fi
git lfs install --local
git fetch -q --depth 1 origin "$commit"
git checkout -q FETCH_HEAD
git lfs pull origin
git lfs fsck

if [ -f "$top/fixes/$name.sh" ]; then
	sh "$top/fixes/$name.sh"
fi

if [ -n "$version" ]; then
	source=$(sed -n 's/^Source: *//p' debian/control)
	{
		echo "$source ($version) unstable; urgency=medium"
		echo
		echo "  * Built from $url at $commit."
		echo
		echo " -- ycderman <y.canderman@proton.me>  $(date -R)"
		echo
		cat debian/changelog
	} > debian/changelog.new
	mv debian/changelog.new debian/changelog
fi

apt-get build-dep -y -q ./
dpkg-buildpackage -b -us -uc

mv ../*.deb "$top/out/"
ls -l "$top/out"
