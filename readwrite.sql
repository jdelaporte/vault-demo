CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
COMMENT on ROLE "{{name}}" IS 'Role managed by Vault';
GRANT CONNECT ON DATABASE demoapp TO "{{name}}";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "{{name}}";
