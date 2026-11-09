#!/bin/bash
# https://gist.github.com/anthonyclarka2/c8968122ee8b1f84951e0e83ae05a543

# This script gets your current AWS role and dumps the IAM policies associated with that role
# Requires the iam:ListRolePolicies and iam:ListAttachedRolePolicies permissions
# Requires the aws cli and the jq utility
# Creative Commons Attribution-Sharealike: https://creativecommons.org/licenses/by-sa/4.0/

# TODO: compare jq vs the query parameter in the aws cli, see if there's any difference in speed or results

if [ "x$1" != "x" ]; then
  MY_ROLE="$1"
else
  MY_ROLE=$(aws sts get-caller-identity | jq -r '.Arn' | cut -d'/' -f2)
fi

ROLE_POLS=$(aws iam list-role-policies --role-name "${MY_ROLE}" | jq -r '.PolicyNames[]' | tr '\n' ',')
IFS=',' read -r -a ROLE_POLICIES <<< "$ROLE_POLS"

for POLICY in "${ROLE_POLICIES[@]}"
do
  echo "${POLICY}"
  POL_VER=$(aws iam get-role-policy --policy-name "${POLICY}" --role-name "${MY_ROLE}" | jq -r '.Policy.DefaultVersionId')
  aws iam get-role-policy --policy-name "${POLICY}" --role-name "${MY_ROLE}" | jq -r '.PolicyDocument.Statement'
  echo
done

echo
echo

ATTD_POLS=$(aws iam list-attached-role-policies --role-name "${MY_ROLE}" | jq -r '.AttachedPolicies[].PolicyArn' | tr '\n' ',')
IFS=',' read -r -a ATTD_POLICIES <<< "$ATTD_POLS"

for POLICY in "${ATTD_POLICIES[@]}"
do
  echo "${POLICY}"
  POL_VER=$(aws iam get-policy --policy-arn "${POLICY}" | jq -r '.Policy.DefaultVersionId')
  aws iam get-policy-version --policy-arn "${POLICY}" --version-id "${POL_VER}" | jq -r '.PolicyVersion.Document.Statement'
  echo
done
