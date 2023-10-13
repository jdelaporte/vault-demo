pid_file = "./pidfile"

vault {
  address = "http://127.0.0.1:8200"
}

auto_auth {
  method {
    type      = "approle"

    mount_path = "auth/demoapp"
    config = {
      role_id_file_path = "roleid"
      secret_id_file_path = "secretid"
      remove_secret_id_file_after_reading = false
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
  source      = "pg_rw_config.yml.tpl"
  destination = "rw_config_output.yml"
}