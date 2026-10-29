# Debian has no adwaita-icon-theme-full; its adwaita-icon-theme is already the full set.
sed -i 's/adwaita-icon-theme-full/adwaita-icon-theme/' debian/control
