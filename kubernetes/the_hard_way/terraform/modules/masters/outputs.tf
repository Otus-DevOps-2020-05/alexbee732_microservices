output "ips" {
  value = yandex_compute_instance.masters[*].network_interface[0].ip_address
}
