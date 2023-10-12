---
Template: Config2
{{- with secret "database/creds/readwrite" }}
username: "{{ .Data.username }}"
password: "{{ .Data.password }}"
database: "demoapp"
{{- end }}