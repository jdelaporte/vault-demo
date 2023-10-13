---
Template: Config2
{{- with secret "database/creds/pg_readwrite" }}
username: "{{ .Data.username }}"
password: "{{ .Data.password }}"
database: "demoapp"
{{- end }}