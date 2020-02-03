#!/usr/bin/env bash

# Bitbucket API Documentation: https://developer.atlassian.com/bitbucket/api/2/reference/

function print_help {
echo -e "Remove current restrictions and set a new ones

Required parameters:
    --client-id|BITBUCKET_CLIENT_ID - Bitbucket OAuth consumer key
    --client-secret|BITBUCKET_CLIENT_SECRET - Bitbucket OAuth consumer secret
    --workspace|BITBUCKET_WORKSPACE - Bitbucket workspace
    --project|BITBUCKET_PROJECT - Bitbucket project

Optional parameters:
    --repo|BITBUCKET_REPO - Bitbucket repository
"
}

function set_restriction {
  branch_restrictions_json="{\"kind\": \"\", \"pattern\": \"\", \"value\": 1, \"branch_match_kind\": \"glob\", \"type\": \"branchrestriction\"}"
  access_token=$1
  repo=$2
  branch=$3
  kind=$4
  value=$5
  users=$6
  groups=$7

  json=$(echo "${branch_restrictions_json}" | jq -r ".value=${value} | .pattern=\"${branch}\" | .kind=\"${kind}\" | .users=${users} | .groups=${groups}")
  response=$(curl -s -q -X POST -H "Authorization: Bearer ${access_token}" \
                  -H "Content-Type: application/json" -d "${json}" "$repo/branch-restrictions")
  type=$(echo "${response}" | jq -r ".type")
  if [[ $type = "error" ]]; then echo "${response}" | jq -r ".error.message"; fi
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case ${key} in
    --client-id)
    BITBUCKET_CLIENT_ID="$2"
    shift # past argument
    shift # past value
    ;;
    --client-secret)
    BITBUCKET_CLIENT_SECRET="$2"
    shift # past argument
    shift # past value
    ;;
    --project)
    BITBUCKET_PROJECT="$2"
    shift # past argument
    shift # past value
    ;;
    --repo)
    BITBUCKET_REPO="$2"
    shift # past argument
    shift # past value
    ;;
    --workspace)
    BITBUCKET_WORKSPACE="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ -z ${BITBUCKET_CLIENT_ID} ]]; then echo "--client-id is required"; exit 1; fi
if [[ -z ${BITBUCKET_CLIENT_SECRET} ]]; then echo "--client-secret is required"; exit 1; fi
if [[ -z ${BITBUCKET_PROJECT} ]]; then echo "--project is required"; exit 1; fi
if [[ -z ${BITBUCKET_WORKSPACE} ]]; then echo "--workspace is required"; exit 1; fi

# https://developer.atlassian.com/bitbucket/api/2/reference/meta/authentication
# Bitbucket Cloud OAuth 2.0, section 4.4 Client Credentials Grant
# Obtain OAuth2 access token
access_token=$(curl -s -X POST -u "${BITBUCKET_CLIENT_ID}:${BITBUCKET_CLIENT_SECRET}" \
"https://bitbucket.org/site/oauth2/access_token" -d grant_type=client_credentials | jq -r ".access_token")

# Get max 100 git repositories from the Bitbucket ${BITBUCKET_WORKSPACE}/${BITBUCKET_PROJECT}
if [[ -z ${BITBUCKET_REPO} ]]
then
  BITBUCKET_API_FILTER="project.key+%7E+%22${BITBUCKET_PROJECT}%22"
else
  BITBUCKET_API_FILTER="project.key+%7E+%22${BITBUCKET_PROJECT}%22+AND+name+%7E+%22${BITBUCKET_REPO}%22"
fi

repos=$(curl -s -X GET -H "Authorization: Bearer ${access_token}" \
  "https://api.bitbucket.org/2.0/repositories/${BITBUCKET_WORKSPACE}?pagelen=100&q=${BITBUCKET_API_FILTER}")

dev_groups="[{\"owner\": {\"username\": \"${BITBUCKET_WORKSPACE}\"},\"slug\": \"developers\"}]"
prj_admin_groups="[{\"owner\": {\"username\": \"${BITBUCKET_WORKSPACE}\"},\"slug\": \"projectadministrators\"}]"

## Walk through every repo in the list
echo "${repos}" | jq -r ".values[].links.self.href" |
while read repo; do
  echo "$repo"
  # Get branch restrictions
  branch_restrictions=$(curl -s -q -X GET -H "Authorization: Bearer ${access_token}" \
         "$repo/branch-restrictions?pagelen=20" | jq .)

  branch_restrictions_size=$(echo "$branch_restrictions" | jq -r ".size")
  if [[ $branch_restrictions_size != 0 ]];
  then
    ## Remove all restrictions
    echo "${branch_restrictions}" | jq -r ".values[].id" |
    while read branch_restriction_id; do
      response=$(curl -s -q -X DELETE -H "Authorization: Bearer ${access_token}" \
                      "$repo/branch-restrictions/${branch_restriction_id}")
      type=$(echo "${response}" | jq -r ".type")
      if [[ $type = "error" ]]; then echo "${response}" | jq -r ".error.message"; fi
    done
  fi

  # Set new restrictions
  set_restriction "${access_token}" "${repo}" "develop" "require_approvals_to_merge" 1 "[]" "[]"
  set_restriction "${access_token}" "${repo}" "develop" "require_passing_builds_to_merge" 1 "[]" "[]"
  set_restriction "${access_token}" "${repo}" "develop" "require_tasks_to_be_completed" null "[]" "[]"
  set_restriction "${access_token}" "${repo}" "develop" "reset_pullrequest_approvals_on_change" null "[]" "[]"
  set_restriction "${access_token}" "${repo}" "develop" "enforce_merge_checks" null "[]" "[]"
  set_restriction "${access_token}" "${repo}" "develop" "restrict_merges" null "[]" "${dev_groups}"
  set_restriction "${access_token}" "${repo}" "develop" "push" null "[]" "${prj_admin_groups}"
  set_restriction "${access_token}" "${repo}" "develop" "force" null "[]" "[]"
  set_restriction "${access_token}" "${repo}" "develop" "delete" null "[]" "[]"

  set_restriction "${access_token}" "${repo}" "master" "restrict_merges" null "[]" "${prj_admin_groups}"
  set_restriction "${access_token}" "${repo}" "master" "push" null "[]" "${prj_admin_groups}"
  set_restriction "${access_token}" "${repo}" "master" "force" null "[]" "[]"
  set_restriction "${access_token}" "${repo}" "master" "delete" null "[]" "[]"
done;
