resource "yandex_compute_instance" "workers" {
  count = var.workers_count

  name = "worker-${count.index}"
  hostname = "worker-${count.index}"

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
    ip_address = "10.240.0.2${count.index}"
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
    serial-port-enable=1
    pod-cidr="10.200.${count.index}.0/24"
  }
}
