# PKI Tutorial
From https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-acme-caddy

## Prerequisites
* Vault CL installed and in PATH

```
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install vault

which vault
```

* curl CLI installed and in PATH
```which curl```

* Docker installed

Don't do this: 
```
sudo apt install docker.io
```

Instead, install Docker Desktop for Windows, and set it up to use WSL 2.
https://docs.docker.com/desktop/wsl/
```
apt-get purge docker.io
```


* jq installed and in system PATH
```
sudo apt install jq
which jq
```

### On Windows, before all that
Install or Upgrade to WSL 2, and install a Linux distro. 
This can be a messy and convoluted process. I needed to start here: https://learn.microsoft.com/en-us/windows/wsl/install#upgrade-version-from-wsl-1-to-wsl-2

I am using Ubuntu-22.04 and WSL 2 now.

In order to write this guide into GitHub and track my work:

Generate an ssh key pair
```
ssh-keygen
```

Add public key to GitHub
```
cat ~/.ssh/id_rsa.pub
``` 
Then, copy/paste into user Settings -> SSH and GPG Keys -> New SSH key

Clone this repo locally
```
cd $HOME/gitstuff
git clone git@github.com:jdelaporte/vault-demo.git
```

Set vim as default editor (please die, Nano)
``` 
sudo update-alternatives --config editor
```

## Demo Set up Steps and Issues
1. Create /tmp/learn-vault-pki
```
mkdir /tmp/learn-vault-pki
```

2. Export /tmp/learn-vault-pki as HC_LEARN_LAB
```
export HC_LEARN_LAB=/tmp/learn-vault-pki
```

3. Create a learn-vault Docker network
```
docker network create \
    --driver=bridge \
    --subnet=10.1.1.0/24 \
    learn-vault
```

4. Error
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```
This issue is complex (and old). The Docker-recommended workaround is to remove all WSL-installed Docker versions, and install Docker Desktop and configure it to use WSL.
https://docs.docker.com/desktop/wsl/

## Deploy Caddy
1. Pull the container image
```
docker pull caddy:latest
```

2. Make directories for caddy config and data
```
mkdir "$HC_LEARN_LAB"/caddy_config "$HC_LEARN_LAB"/caddy_data
```

3. Make Hello World file
```
echo "hello world" > "$HC_LEARN_LAB"/index.html
```

4. Run the caddy container
```
 docker run \
    --name caddy-server \
    --hostname caddy-server \
    --network learn-vault \
    --ip 10.1.1.200 \
    --publish 80:80 \
    --volume "$HC_LEARN_LAB"/index.html:/usr/share/caddy/index.html \
    --volume "$HC_LEARN_LAB"/caddy_data:/data \
    --detach \
    --rm \
    caddy
```

## Connect to HCP Vault 
Set up a project and Vault cluster on HashiCorp Cloud Platform: https://portal.cloud.hashicorp.com

Go to the Vault Cluster overview.
Export the environment variables:
```
export VAULT_ADDR="https://pki-cluster-public-vault-<ID>.hashicorp.cloud:8200";
export VAULT_NAMESPACE="admin"
```

Authenticate with AppRole and store the client token:
```
export VAULT_TOKEN=$(curl -s --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
    --request POST --data '{"role_id": "<role_id>", "secret_id": "<secret_id>"}' \
     $VAULT_ADDR/v1/auth/approle/login | jq -r '.auth.client_token' )
```

Issue a leaf certificate from the AppRole, and save it to a file:
```
curl -s --header "X-Vault-Namespace: $VAULT_NAMESPACE" \
    --header "X-Vault-Token: $VAULT_TOKEN" -X PUT \
    -d '{"common_name":"hcp-magic.example.com"}' \
    $VAULT_ADDR/v1/example-pki/issue/my-first-vault-cert | jq -r ".data.certificate" > example-cert.pem
```

Check the certficate:
```
openssl x509 -in example-cert.pem -text -noout
```