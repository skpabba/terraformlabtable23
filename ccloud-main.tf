# --------------------------------------------------------
# This 'random_id' will make whatever you create (names, etc)
# unique in your account.
# --------------------------------------------------------
resource "random_id" "id" {
    byte_length = 4
}
# -------------------------------------------------------
# Environment
# -------------------------------------------------------
resource "confluent_environment" "simple_env" {
    display_name = "${local.env_name}-${random_id.id.hex}"
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# Schema Registry
# --------------------------------------------------------
data "confluent_schema_registry_region" "simple_sr_region" {
    cloud = "AWS"
    region = "us-east-2"
    package = "ESSENTIALS" 
}
resource "confluent_schema_registry_cluster" "simple_sr_cluster" {
    package = data.confluent_schema_registry_region.simple_sr_region.package
    environment {
        id = confluent_environment.simple_env.id 
    }
    region {
        id = data.confluent_schema_registry_region.simple_sr_region.id
    }
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# Cluster
# --------------------------------------------------------
resource "confluent_kafka_cluster" "simple_cluster" {
    display_name = "${local.cluster_name}"
    availability = "SINGLE_ZONE"
    cloud = "AWS"
    region = "us-east-1"
    basic {}
    environment {
        id = confluent_environment.simple_env.id
    }
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# Connectors
# --------------------------------------------------------
resource "confluent_connector" "sink" {
  environment {
    id = confluent_environment.simple_env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.simple_cluster.id
  }

  // Block for custom *sensitive* configuration properties that are labelled with "Type: password" under "Configuration Properties" section in the docs:
  // https://docs.confluent.io/cloud/current/connectors/cc-s3-sink.html#configuration-properties
  config_sensitive = {
    "aws.access.key.id"     = "${var.aws_access_key_id}"
    "aws.secret.access.key" = "${var.aws_secret_access_key}"
  }

  // Block for custom *nonsensitive* configuration properties that are *not* labelled with "Type: password" under "Configuration Properties" section in the docs:
  // https://docs.confluent.io/cloud/current/connectors/cc-s3-sink.html#configuration-properties
  config_nonsensitive = {
    "topics"                   = "product"
    "input.data.format"        = "JSON"
    "connector.class"          = "S3_SINK"
    "name"                     = "S3_SINKConnector_0"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.sinkconnector.id
    "s3.bucket.name"           = "terraformlabtable23"
    "output.data.format"       = "JSON"
    "time.interval"            = "DAILY"
    "flush.size"               = "1000"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_kafka_acl.connectors_source_acl_describe_cluster,
    confluent_kafka_acl.connectors_source_acl_read
  ]

  lifecycle {
    prevent_destroy = false
  }
}


# --------------------------------------------------------
# Service Accounts
# --------------------------------------------------------
resource "confluent_service_account" "app_manager" {
    display_name = "app-manager-${random_id.id.hex}"
    description = "${local.description}"
}
resource "confluent_service_account" "sr" {
    display_name = "sr-${random_id.id.hex}"
    description = "${local.description}"
}
resource "confluent_service_account" "sinkconnector" {
    display_name = "sinkconnector-sa-${random_id.id.hex}"
    description = "${local.description}"
}
# --------------------------------------------------------
# Role Bindings
# --------------------------------------------------------
resource "confluent_role_binding" "app_manager_environment_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.simple_env.resource_name
}
resource "confluent_role_binding" "sr_environment_admin" {
    principal = "User:${confluent_service_account.sr.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.simple_env.resource_name
}
# --------------------------------------------------------
# Credentials
# --------------------------------------------------------
resource "confluent_api_key" "app_manager_kafka_cluster_key" {
    display_name = "app-manager-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.app_manager.id
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.simple_cluster.id
        api_version = confluent_kafka_cluster.simple_cluster.api_version
        kind = confluent_kafka_cluster.simple_cluster.kind
        environment {
            id = confluent_environment.simple_env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_environment_admin
    ]
}
resource "confluent_api_key" "sr_cluster_key" {
    display_name = "sr-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.sr.id 
        api_version = confluent_service_account.sr.api_version
        kind = confluent_service_account.sr.kind
    }
    managed_resource {
        id = confluent_schema_registry_cluster.simple_sr_cluster.id
        api_version = confluent_schema_registry_cluster.simple_sr_cluster.api_version
        kind = confluent_schema_registry_cluster.simple_sr_cluster.kind 
        environment {
            id = confluent_environment.simple_env.id
        }
    }
    depends_on = [
      confluent_role_binding.sr_environment_admin
    ]
}
resource "confluent_api_key" "sinkconnector_keys" {
    display_name = "sinkconnector-api-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.sinkconnector.id
        api_version = confluent_service_account.sinkconnector.api_version
        kind = confluent_service_account.sinkconnector.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.simple_cluster.id
        api_version = confluent_kafka_cluster.simple_cluster.api_version
        kind = confluent_kafka_cluster.simple_cluster.kind
        environment {
            id = confluent_environment.simple_env.id
        }
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_describe_cluster,
        confluent_kafka_acl.connectors_source_acl_read
    ]
}

# ------------------------------------------------------
# ACLS
# ------------------------------------------------------
resource "confluent_kafka_acl" "connectors_source_acl_describe_cluster" {
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    resource_type = "CLUSTER"
    resource_name = "kafka-cluster"
    pattern_type = "LITERAL"
    principal = "User:${confluent_service_account.sinkconnector.id}"
    operation = "DESCRIBE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.simple_cluster.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_kafka_cluster_key.id
        secret = confluent_api_key.app_manager_kafka_cluster_key.secret
    }
}

resource "confluent_kafka_acl" "connectors_source_acl_read" {
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    resource_type = "TOPIC"
    resource_name = "product"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.sinkconnector.id}"
    operation = "READ"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.simple_cluster.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_kafka_cluster_key.id
        secret = confluent_api_key.app_manager_kafka_cluster_key.secret
    }
}