# Dynamic Database Credentials with HashiCorp Vault
From https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets
and 
https://developer.hashicorp.com/vault/tutorials/app-integration/application-integration


* HCP or Vault Community Edition environment
* PostgreSQL (postgres Docker container works)
* jq
* ngrok installed and configured with an auth token (HCP Vault only)

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

Configure a postgesql secrets engine.
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

