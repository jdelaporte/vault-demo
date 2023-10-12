# From https://developer.hashicorp.com/vault/docs/agent-and-proxy/autoauth/methods/token_file

pid_file = "./pidfile"

vault {
  address = "https://127.0.0.1:8200"
}

auto_auth {
  method {
    type = "token_file"

    config = {
      token_file_path = "./vault-token"
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
  source      = "pg_ro_config.yml.tpl"
  destination = "ro_config_output.yml"
}
