# Dynamic Database Credentials with HashiCorp Vault
From https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets
and 
https://developer.hashicorp.com/vault/tutorials/app-integration/application-integration


* HCP or Vault Community Edition environment
* PostgreSQL (postgres Docker container works)
* jq
* ngrok installed and configured with an auth token (HCP Vault only)
* consul-template
* postgresql-client on local demo system

## Set up Postgres

Pull the postgres image
```
docker pull postgres:latest
```

Start the contanier
```
docker run \
    --detach \
    --name learn-postgres \
    -e POSTGRES_USER=root \
    -e POSTGRES_PASSWORD=rootpassword \
    -p 5432:5432 \
    --rm \
    postgres
```

Verify container is running
```
docker ps -f name=learn-postgres --format "table {{.Names}}\t{{.Status}}"
```

Connect to database
```
docker exec -it learn-postgres psql
```

Create a read-only role in postgres database
If connected to psql as above, use the psql command directly:
```
docker exec -it learn-postgres psql
```
Or, pass the command into the container:
```
docker exec -i \
    learn-postgres \
    psql -U root -c "CREATE ROLE \"ro\" NOINHERIT;"
```

## Start vault cluster
```
vault server -dev -dev-root-token-id root
```

In a new terminal, set up the env
```
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
export POSTGRES_URL=127.0.0.1:5432
```

## Set up database secrets engine
```
vault secrets enable database
```

Configure a postgresql secrets engine.
This step also verifies the connection.
If your Vault cluster cannot reach or authenticate to your database, it will fail.
If your database doesn't exist, it will fail.
```
vault write database/config/postgresql \
      plugin_name=postgresql-database-plugin \
      allowed_roles=readonly \
      connection_url="postgresql://{{username}}:{{password}}@$POSTGRES_URL/myapp?sslmode=disable" \
      username=root \
      password=rootpassword
```

Create file that defines a Vault role
```
tee readonly.sql <<EOF
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
EOF
```

Create the Vault role:

The `db_name` value *must match* the database secrets engine object created earlier.
```
vault write database/roles/readonly db_name=postgresql \
        creation_statements=@readonly.sql \
        default_ttl=1h max_ttl=24h
```

View the Vault Role:
```
vault read database/roles/readonly
```

Create/retrieve a credential from the role:
```
vault read database/creds/readonly
```

## Consul Template - Vault Client Config
Create a policy file for Consul Template.
This allows the vault client to read the credentials under the readonly role, and to renew leases for the (which) role(s)?
```
tee db_creds.hcl <<EOF
path "database/creds/readonly" {
  capabilities = [ "read" ]
}

path "sys/leases/renew" {
  capabilities = [ "update" ]
}
EOF
```

Create the policy from the file:
```
vault policy write db_creds db_creds.hcl
```

Create a token from the policy created for the consul template
```
DB_TOKEN=$(vault token create -policy="db_creds" -format json | jq -r '.auth | .client_token')
```

## Consul Template - DB Config
Create a Consul Template file
```
$ tee config.yml.tpl <<EOF
---
{{- with secret "database/creds/readonly" }}
username: "{{ .Data.username }}"
password: "{{ .Data.password }}"
database: "myapp"
{{- end }}
EOF
```

Create a db config file from the consul template, and verify
```
$ VAULT_TOKEN=$DB_TOKEN consul-template \
        -template="config.yml.tpl:config.yml" -once

$ cat config.yml
```

## Set up Envconsul to Retrieve DB credentials
https://developer.hashicorp.com/vault/tutorials/app-integration/application-integration#step-4-use-envconsul-to-retrieve-db-credentials


## Extra Credit: Secure Postgresql Root Password
https://developer.hashicorp.com/vault/tutorials/db-credentials/database-root-rotation
Rotate the root credential easily with the `rotate-root` Vault path.
Use the same secrets engine endpoint (eg; postgresql).
Be sure to create a different superuser in the db first.
```
vault write - force database/rotate-root/postgresql
```