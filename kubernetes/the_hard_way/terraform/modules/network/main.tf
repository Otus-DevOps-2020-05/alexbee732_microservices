resource "yandex_vpc_network" "app-network" {
  name = "kubernetes-the-hard-way"
}

resource "yandex_vpc_route_table" "kubernetes-route" {
  name = "kubernetes-route"
  network_id = "${yandex_vpc_network.app-network.id}"

  static_route {
    destination_prefix = "10.200.0.0/24"
    next_hop_address   = "10.240.0.20"
  }
  static_route {
    destination_prefix = "10.200.1.0/24"
    next_hop_address   = "10.240.0.21"
  }
  static_route {
    destination_prefix = "10.200.2.0/24"
    next_hop_address   = "10.240.0.22"
  }
}

resource "yandex_vpc_subnet" "app-subnet" {
  name           = "kubernetes"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.app-network.id
  v4_cidr_blocks = ["10.240.0.0/24"]
}
