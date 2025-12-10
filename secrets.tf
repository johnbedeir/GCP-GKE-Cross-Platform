####################################################################################################
###                                                                                              ###
###                                    GCP Secret Manager                                        ###
###                                                                                              ###
####################################################################################################

# Datadog API Key Secret for GKE Production Cluster
resource "google_secret_manager_secret" "datadog_api_key" {
  secret_id = var.datadog_api_secret_name

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    budget = var.proc_budget
  }
}

resource "google_secret_manager_secret_version" "datadog_api_key" {
  secret      = google_secret_manager_secret.datadog_api_key.id
  secret_data = var.datadog_api_key_value

  lifecycle {
    ignore_changes = [secret_data]
  }
}

# Datadog API Key Secret for GKE GitOps Cluster
resource "google_secret_manager_secret" "gitops_datadog_api_key" {
  secret_id = var.gitops_datadog_api_secret_name

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = {
    budget = var.proc_budget
  }
}

resource "google_secret_manager_secret_version" "gitops_datadog_api_key" {
  secret      = google_secret_manager_secret.gitops_datadog_api_key.id
  secret_data = var.gitops_datadog_api_key_value

  lifecycle {
    ignore_changes = [secret_data]
  }
}

