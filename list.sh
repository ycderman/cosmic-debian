#!/bin/sh
# Print what to build for one COSMIC release, one package per line:
#
#   <name> <git url> <commit> [version]
#
#   sh list.sh epoch-1.11.0
set -eu

tag=$1
version=${tag#epoch-}

# No debian/ folder upstream.
skip="cosmic-sound-theme"

git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" https://github.com/pop-os/cosmic-epoch.git epoch
cd epoch

git config -f .gitmodules --get-regexp '\.path$' | while read -r key path; do
	name=${key#submodule.}
	name=${name%.path}
	case " $skip " in *" $path "*) continue ;; esac
	url=$(git config -f .gitmodules "submodule.$name.url")
	commit=$(git ls-tree HEAD "$path" | awk '{print $3}')
	echo "$path $url $commit $version-1"
done

# Pop!_OS icons, fonts, sounds and GTK theme that COSMIC depends on.
for repo in icon-theme fonts gtk-theme adw-gtk3; do
	url=https://github.com/pop-os/$repo.git
	commit=$(git ls-remote "$url" HEAD | cut -f1)
	echo "$repo $url $commit"
done
