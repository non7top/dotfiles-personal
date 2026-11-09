#!/usr/bin/env bash
ns=$1
role=$2

echo

_tab() {
    printf "%30s   %s\n" $1 $2
}
export -f _tab

_tab "approle" "${ns}/auth/approle/role/${role}"

vault_approle_role_id=$(vault read ${ns}/auth/approle/role/${role}/role-id -format=json |jq -r .data.role_id)
_tab "vault_approle_role_id" $vault_approle_role_id

vault_approle_secret_id=$(vault write -f ${ns}/auth/approle/role/${role}/secret-id -format=json |jq -r .data.secret_id)
_tab "vault_approle_secret_id" $vault_approle_secret_id

vault_aws_role=$( vault read ${ns}/auth/approle/role/${role} -format=json|jq -r '.data.token_policies[]|select(endswith("-sts"))')
_tab "vault_aws_role" "$vault_aws_role"

iam_roles=$( vault read ${ns}/aws/roles/${role} -format=json|jq -r .data.role_arns[])
_tab "iam_roles" " "
echo "$iam_roles" | xargs -n1 -I {} bash -c '_tab - {}'
