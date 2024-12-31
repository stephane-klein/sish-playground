#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../"

export TF_VAR_powerdns_ip=$(terraform output --json | jq -r '.server1_public_ip | .value')
export TF_VAR_server_ip=$(terraform output --json | jq -r '.server1_public_ip | .value')

terraform -chdir=dns_records init
terraform -chdir=dns_records apply
