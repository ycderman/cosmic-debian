# appstream-data-pop is the app list of the Pop!_OS archive. Debian ships its own.
sed -i '/appstream-data-pop/d' debian/control
