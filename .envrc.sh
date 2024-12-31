source .secret

export SCW_DEFAULT_ORGANIZATION_ID="215d7434-7429-43e4-b93f-edfd57e2677d" # Get it, in https://console.scaleway.com/organization/settings
export SCW_ACCESS_KEY="SCW55S8FG6JXD7A36C5R"

export SERVER1_IP=$(terraform output --json | jq -r '.server1_public_ip.value // empty')
