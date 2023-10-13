CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
COMMENT on ROLE "{{name}}" IS 'Role managed by Vault';
GRANT CONNECT ON DATABASE demoapp TO "{{name}}";
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{{name}}";
GRANT ALL ON ALL SEQUENCES IN SCHEMA public to "{{name}}";