# Dynamic Database Credentials with HashiCorp Vault
From https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets
and 
https://developer.hashicorp.com/vault/tutorials/app-integration/application-integration

## Prerequisites
* HCP or Vault Community Edition environment
* PostgreSQL (postgres Docker container works)
* jq
* ngrok installed and configured with an auth token (HCP Vault only)
* consul-template apt package
* envconsul apt package
* postgresql-client apt package

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
If your Vault cluster cannot reach your postgresql server, it will fail.
If the user (`db_admin_vault`) cannot authenticate or is not authorized on the database (`demoapp`), this will fail.
If your database (example here: `demoapp`) doesn't exist, it will fail.
You will need to remember the secrets engine path endpoint for the later steps (`postgresql` in this example)
```
vault write database/config/postgresql \
      plugin_name=postgresql-database-plugin \
      allowed_roles=readonly,pg_readwrite \
      connection_url="postgresql://{{username}}:{{password}}@$POSTGRES_URL/demoapp?sslmode=disable" \
      username=db_admin_vault \
      password=insecure_password   <------ After rotating root pass, leave out this param         
```

## Create a Read Only Database User Role
Create file that defines a Vault role to create a read only postgres user:
```
tee readonly.sql <<EOF
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
COMMENT on ROLE "{{name}}" IS 'Role managed by Vault';
GRANT CONNECT ON DATABASE demoapp TO "{{name}}";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
EOF
```

Create the Vault role which can create credentials for readonly postgres users:

The `db_name` value *must match* the database secrets engine object created earlier (not the postgres database). In this example, it is `postgresql`.
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

List the generated leases for the readonly database role:
```
vault list sys/leases/lookup/database/creds/readonly
```

## Create a Database User Role with more Privileges
Create the Vault role which can create credentials for read-write postgres users:

The `db_name` value *must match* the database secrets engine object created earlier (not the postgres database). In this example, it is `postgresql`.
```
vault write database/roles/pg_readwrite db_name=postgresql \
        creation_statements=@readwrite.sql \
        default_ttl=10m max_ttl=24h
```

View the Vault Role:
```
vault read database/roles/pg_readwrite
```

Create/retrieve a credential from the role:
```
vault read database/creds/pg_readwrite
```

List the generated leases for the readonly database role:
```
vault list sys/leases/lookup/database/creds/pg_readwrite
```


## Verify the Role(s) in Postgres
Connect to postgresql as an admin user:
```
psql -h <host> -d <database> -U <user> -p <port>
```
or, if running container you can use this to connect:
```
docker exec -ti <container-name> psql -d postgres -U <user>
```

Then run the query to list roles:
```
SELECT rolname FROM pg_roles;
```

## Consul Template - Vault Client Config
Create a policy file for readonly db access  via Consul Template.
This allows the vault client to read the credentials under the readonly role, and to renew leases for the (which) role(s)?
```
tee pg_ro_pol.hcl <<EOF
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
vault policy write pg_ro pg_ro_pol.hcl
```

Create a token from the policy created for the consul template
```
export VAULT_ADDR=http://127.0.0.1:8200   <---- if using an insecure dev client connection
DB_TOKEN=$(vault token create -policy="pg_ro" -format json | jq -r '.auth | .client_token')
```

## Consul Template - DB Config (Readonly Role)
Create a Consul Template file
```
$ tee pg_ro_config.yml.tpl <<EOF
---
{{- with secret "database/creds/readonly" }}
username: "{{ .Data.username }}"
password: "{{ .Data.password }}"
database: "demoapp"
{{- end }}
EOF
```

Create a readonly db config file from the consul template, and verify

```
export VAULT_ADDR=http://127.0.0.1:8200  <---- Replace with your Vault cluster URL 
VAULT_TOKEN=$DB_TOKEN consul-template \
        -template="pg_ro_config.yml.tpl:pg_ro_config.yml" -once

cat pg_ro_config.yml
```

## Set up Envconsul to Retrieve DB credentials (Readonly Role)
https://developer.hashicorp.com/vault/tutorials/app-integration/application-integration#step-4-use-envconsul-to-retrieve-db-credentials


Create a micro app that reads environment variables
```
tee app.sh <<EOF
#!/usr/bin/env bash

cat <<EOT
My connection info is:

username: "\${DATABASE_CREDS_READONLY_USERNAME}"   <---- How does this handle role names with underscores?
password: "\${DATABASE_CREDS_READONLY_PASSWORD}"
database: "demoapp"
EOT
EOF
chmod +x app.sh
```

Run envconsul to retrieve database credentials from the readonly role
```
export VAULT_ADDR=http://127.0.0.1:8200  <---- 
VAULT_TOKEN=$DB_TOKEN envconsul -upcase -secret database/creds/readonly ./app.sh
```

## Vault Agent with Auto-auth
There are many ways to authenticate the Vault agent. The simplest is the token file, but it is only for development. 

### Auto-auth with token file
From https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/token_file

```
pid_file = "./pidfile"

vault {
  address = "https://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "token_file"

    config = {
      token_file_path = "/home/username/.vault-token"
    }
  }
}

api_proxy {
  use_auto_auth_token = true
}

listener "tcp" {
  address = "127.0.0.1:8100"
  tls_disable = true
}

template {
  source      = "/etc/vault/server.key.ctmpl"
  destination = "/etc/vault/server.key"
}

template {
  source      = "/etc/vault/server.crt.ctmpl"
  destination = "/etc/vault/server.crt"
}
```
## Extra Credit: Set up AppRole
Enable the approle auth method
```
vault auth enable -path=demoapp approle
```

Create a policy to apply to the AppRole
```
vault policy write demoapp_pg_rw pg_rw_pol.hcl
```

Create a role for granting read-write creds to postgres:

? - How do I attach a policy to this auth method to restrict access to the read-write postgres database secrets engine path?

```
vault write auth/demoapp/role/pg_rw \
    secret_id_ttl=10m \
    token_num_uses=0 \    <---- Must be 0 to create child tokens!
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=0 \
    token_policies=demoapp_pg_rw
```

Get the RoleID
```
vault read auth/demoapp/role/pg_rw/role-id
```

Get a SecretID from the AppRole
```
vault write -f auth/demoapp/role/pg_rw/secret-id
```

### Auto-auth with AppRole
```
vault agent -config agent-approle.hcl  <---- Getting permission denied.
```

It's trying to access `http://127.0.0.1:8200/v1/auth/approle/login` rather than the path configured for the role-id. Need to specify path in the agent when customized auth engine path is used.

Another error
```
vault write auth/demoapp/role/pg_rw/login role_id=007932a8-d695-b073-0d3e-db82ccfaf8eb secret_id=3e83e50b-e22d-e2b8-ca2c-3dded1d8e812
Error writing data to auth/demoapp/role/pg_rw/login: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/auth/demoapp/role/pg_rw/login
Code: 404. Errors:

* 1 error occurred:
        * unsupported path

```

## Extra Credit: Secure Postgresql Root Password
https://developer.hashicorp.com/vault/tutorials/db-credentials/database-root-rotation

The admin/root user's password will no longer be retrievable. Vault will cache and rotate it, but not return it for external use.

Be sure to create a different superuser in the db and set it up in the Vault config for the database endpoint *first*. You may need to take steps like the following. 

From stack overflow (https://stackoverflow.com/a/53849271):

    Transfer ownership of the database and all schemas and objects in it to the new user.

    Give the user CREATEROLE.

    Make sure to REVOKE CONNECT ON DATABASE <db> FROM PUBLIC. 
    Grant the new user the CONNECT privilege on the database in question.

    Don't give the new user any permissions on other databases or objects therein.

I used these steps:
```
CREATE USER db_admin_vault CREATEROLE;
ALTER USER db_admin_vault WITH PASSWORD 'insecure_password';
ALTER DATABASE demoapp OWNER TO db_admin_vault;
REVOKE CONNECT ON DATABASE demoapp FROM PUBLIC;
```

Go through the steps above to verify that Vault can still create credentials.
Sanity check from Vault
```
vault read database/creds/readonly
```

If you see the following error, you need to change ownership of tables/schema to the new admin user that can CREATE ROLES in postgres:
```
        * failed to execute query: ERROR: permission denied for table appusers (SQLSTATE 42501)
```

Rotate the root credential easily with the `rotate-root` Vault path.
Use the same secrets engine endpoint (eg; postgresql).
```
vault write -force database/rotate-root/postgresql
```