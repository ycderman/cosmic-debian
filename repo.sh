#!/bin/sh
# Turn a folder of .deb files into a signed APT repository.
#
#   sh repo.sh <deb folder> <site folder> <cosmic version>
#
# The signing key must already be in gpg.
set -eu

debs=$1
site=$2
version=$3
dist=dists/forky

mkdir -p "$site/pool" "$site/$dist/main/binary-amd64"
cp "$debs"/*.deb "$site/pool/"
cd "$site"

apt-ftparchive packages pool > "$dist/main/binary-amd64/Packages"
gzip -9kf "$dist/main/binary-amd64/Packages"

apt-ftparchive \
	-o APT::FTPArchive::Release::Origin=cosmic-debian \
	-o APT::FTPArchive::Release::Label=cosmic-debian \
	-o APT::FTPArchive::Release::Suite=forky \
	-o APT::FTPArchive::Release::Codename=forky \
	-o APT::FTPArchive::Release::Architectures=amd64 \
	-o APT::FTPArchive::Release::Components=main \
	release "$dist" > Release
mv Release "$dist/Release"

gpg --batch --yes --armor --detach-sign -o "$dist/Release.gpg" "$dist/Release"
gpg --batch --yes --clearsign -o "$dist/InRelease" "$dist/Release"
gpg --armor --export > key.asc

echo "$version" > version
