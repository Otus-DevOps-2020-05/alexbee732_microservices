resource "yandex_compute_instance" "masters" {
  count = var.masters_count

  name = "master-${count.index}"
  hostname = "master-${count.index}"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id="fd83bj827tp2slnpp7f0"
      size=20
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = true
    ip_address = "10.240.0.1${count.index}"
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
    serial-port-enable=1
  }
}
