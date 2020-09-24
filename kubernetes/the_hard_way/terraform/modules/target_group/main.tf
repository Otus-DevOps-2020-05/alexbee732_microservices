resource "yandex_lb_target_group" "masters_tg" {
  name      = "kubernetes-target-pool"
  region_id = "ru-central1"

  
  dynamic "target" {
    for_each = var.masters_ips
    content {
      subnet_id = var.subnet_id
      address   = target.value
    }
  }
}
