# PKI Tutorial
From https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-acme-caddy

## Prerequisites
Vault CL installed and in PATH
`which vault`

curl CLI installed and in PATH
`which curl`

Docker installed
`which docker`

jq installed and in system PATH
`which jq`

### On Windows, before all that
Install or Upgrade to WSL 2, and install a Linux distro. 
This can be a messy and convoluted process. I needed to start here: https://learn.microsoft.com/en-us/windows/wsl/install#upgrade-version-from-wsl-1-to-wsl-2

I am using Ubuntu-22.04 and WSL 2 now.

In order to write this guide into GitHub and track my work:
Generate an ssh key pair
`ssh-keygen`

Add public key to GitHub
`cat ~/.ssh/id_rsa.pub` and copy/paste into user Settings -> SSH and GPG Keys -> New SSH key

Clone this repo locally
`cd $HOME/gitstuff`
`git clone git@github.com:jdelaporte/vault-demo.git`

Set vim as default editor (please die, Nano)
`sudo update-alternatives --config editor`

