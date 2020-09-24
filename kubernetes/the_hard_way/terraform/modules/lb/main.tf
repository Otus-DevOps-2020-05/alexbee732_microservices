resource "yandex_lb_network_load_balancer" "lb" {
  name = "kubernetes-load-balancer"

  listener {
    name = "kubernetes-listener"
    port = 6443
    external_address_spec {
      ip_version = "ipv4"
      address = var.static_ip
    }
  }

  attached_target_group {
    target_group_id = var.target_group_id

    healthcheck {
      name = "kubernetes-health-check"
      healthy_threshold = 2
      unhealthy_threshold = 2
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}