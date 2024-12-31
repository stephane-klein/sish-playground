terraform {
    required_providers {
        scaleway = {
            source = "scaleway/scaleway"
            version = "2.47.0" # See last version on this url https://github.com/scaleway/terraform-provider-scaleway/releases
        }
    }
}

provider "scaleway" {
    zone   = "fr-par-1"
    region = "fr-par"
}

/* Begin section: create server1 (Virtual Instance) */

resource "scaleway_instance_ip" "server1_public_ip" {
}

resource "scaleway_instance_server" "server1" {
    name = "server1"
    type  = "DEV1-S"
    image = "ubuntu_noble" # Last Ubuntu LTS version 24.04
    # Execute "scw marketplace image list" to comsult the list of images proposed by Scaleway
    ip_id = scaleway_instance_ip.server1_public_ip.id
    root_volume {
        size_in_gb = 20
    }
}

output "server1_public_ip" {
    value = scaleway_instance_ip.server1_public_ip.address
}

/* End section: create server1 (Virtual Instance) */
