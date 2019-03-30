#!/usr/bin/env zsh

# Create and configure global .gitignore
git config --global core.excludesfile ~/.gitignore_global
curl -o ~/.gitignore_global https://gist.githubusercontent.com/octocat/9257657/raw/3f9569e65df83a7b328b39a091f0ce9c6efc6429/.gitignore

# Add my rules
{
    echo
    echo
    echo "# Personal exclusions #"
    echo "#######################"
    echo "out/"
    echo "*.ko"
    echo "Image.*"
    echo "zImage*"
    echo "dtbo*"
    echo "net/wireguard"
    echo "*.rej"
} >> ~/.gitignore_global
