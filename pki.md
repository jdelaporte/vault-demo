# PKI Tutorial
From https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-acme-caddy

## Prerequisites
Vault CL installed and in PATH

```
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

`which vault` 

curl CLI installed and in PATH
`which curl`

Docker installed
Don't do this: `sudo apt install docker.io`
`docker --version`

Instead, install Docker Desktop for Windows, and set it up to use WSL 2.
https://docs.docker.com/desktop/wsl/
`apt-get purge docker.io`


jq installed and in system PATH
`sudo apt install jq`
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

## Steps and Issues
Create /tmp/learn-vault-pki
`mkdir /tmp/learn-vault-pki`

Export /tmp/learn-vault-pki as HC_LEARN_LAB
`export HC_LEARN_LAB=/tmp/learn-vault-pki`

Create a learn-vault Docker network
```docker network create \
    --driver=bridge \
    --subnet=10.1.1.0/24 \
    learn-vault
```
Error: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
This issue is complex, and the Docker-recommended workaround is to install Docker Desktop and configure it to use WSL.
https://docs.docker.com/desktop/wsl/

