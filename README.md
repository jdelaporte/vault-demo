# vault-demo

## Database Credentials - Postgres
[Dynamic DB Credential Management|https://github.com/jdelaporte/vault-demo/blob/main/dynamic_db.md]

The example sets up a database secret engine, with two postgresql roles - read-only and read-write.
A couple of policies are created, to give the consultemplate, envconsul, and vault agent processes restricted access to Vault.
The app role auth method is set up to give the Vault Agent access to the database credential secret engine.
Consultemplate is used to inject rotated database credentials into a file.
Envconsul is used to inject rotated database credentials into environment variables, and execute a script using them.
The Vault Agent is used to rotate credentials parallel to a running application, and inject them into env variables or files.

It also covers what I did for the demo to set up postgres 'root' credential rotation (don't use root, please).
