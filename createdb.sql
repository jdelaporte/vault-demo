CREATE USER db_admin_vault CREATEROLE;
CREATE DATABASE demoapp;
ALTER DATABASE demoapp OWNER TO db_admin_vault;
REVOKE CONNECT ON DATABASE demoapp FROM PUBLIC;
ALTER USER db_admin_vault WITH PASSWORD 'insecure_password';
