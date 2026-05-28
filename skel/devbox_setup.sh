#!/bin/bash


sudo mkdir -p /nix 
sudo chown -R ${USER}:${USER} /nix;
sudo mkdir -p /etc/nix; 
printf "build-users-group =\n" | sudo tee /etc/nix/nix.conf; 

curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --yes --no-modify-profile

. /home/${USER}/.nix-profile/etc/profile.d/nix.sh && nix --version

echo ". /home/$USER/.nix-profile/etc/profile.d/nix.sh" >> /home/$USER/.bashrc; 

wget --quiet --output-document=/dev/stdout https://get.jetify.com/devbox | bash -s -- -f
