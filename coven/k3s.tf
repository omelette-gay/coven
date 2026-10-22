resource "google_secret_manager_secret" "k3s_token" {
  secret_id = "k3s-cluster-token"
  replication {
    auto {}
  }
}
