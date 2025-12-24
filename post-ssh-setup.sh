#!/bin/bash
# Post-SSH Setup
echo "Running post-SSH configuration..."
# Set a welcome message
echo "****************************************" > /etc/motd
echo "* Welcome to your Ubuntu Docker VM      *" >> /etc/motd
echo "* Root login is enabled with 'Passw0rd' *" >> /etc/motd
echo "* Run './build-selector.sh' to start    *" >> /etc/motd
echo "****************************************" >> /etc/motd

# Ensure the build selector is in the root home
if [ -f /media/cidata/build-selector.sh ]; then
    cp /media/cidata/build-selector.sh /root/
    chmod +x /root/build-selector.sh
fi

echo "Post-SSH setup complete."
