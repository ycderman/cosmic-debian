# appstream-data-pop is the app list of the Pop!_OS archive. Debian ships its own.
sed -i '/appstream-data-pop/d' debian/control

# The casper package is only for the Pop!_OS live ISO.
sed -i '/^Package: cosmic-initial-setup-casper/,$d' debian/control
rm -f debian/cosmic-initial-setup-casper.* debian/99cosmic-initial-setup-casper
