path "database/creds/pg_readwrite" {
  capabilities = [ "read" ]
}

path "sys/leases/renew" {
  capabilities = [ "update" ]
}
