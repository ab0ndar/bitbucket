#!/usr/bin/env bash

# Bitbucket API Documentation: https://developer.atlassian.com/bitbucket/api/2/reference/

function print_help {
echo -e "Validate repository. Check:
1. repo has branch 'master'
2. repo has branch 'develop'
3. branch permissions are set

Required parameters:
    --client-id|BITBUCKET_CLIENT_ID - Bitbucket OAuth consumer key
    --client-secret|BITBUCKET_CLIENT_SECRET - Bitbucket OAuth consumer secret
    --workspace|BITBUCKET_WORKSPACE - Bitbucket workspace
    --project|BITBUCKET_PROJECT - Bitbucket project

Optional parameters:
    --repo|BITBUCKET_REPO - Bitbucket repository
"
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

# Walk through every repo in the list
echo "${repos}" | jq -r ".values[].links.self.href" |
while read repo; do
  echo "$repo"

  # Get reference to the develop
  hash=$(curl -s -q -X GET -H "Authorization: Bearer ${access_token}" \
         "$repo/refs/branches?q=name+%7E+%22develop%22" | jq -r ".values[].target.hash")
  if [[ -z ${hash} ]];
  then
    echo "missing develop branch"
  fi

  # Get reference to the master
  hash=$(curl -s -q -X GET -H "Authorization: Bearer ${access_token}" \
         "$repo/refs/branches?q=name+%7E+%22master%22" | jq -r ".values[].target.hash")
  if [[ -z ${hash} ]];
  then
    echo "missing master branch"
  fi

  # Get branch restrictions
  branch_restrictions=$(curl -s -q -X GET -H "Authorization: Bearer ${access_token}" \
         "$repo/branch-restrictions?pagelen=20" | jq .)

  branch_restrictions_size=$(echo $branch_restrictions | jq -r ".size")
  if [[ $branch_restrictions_size == 0 ]];
  then
    echo "missing branch restrictions"
  else
    require_approvals_to_merge=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"require_approvals_to_merge\"))")
    if [[ -z ${require_approvals_to_merge} ]]; then echo "missing require_approvals_to_merge restriction in develop branch"; fi

    require_passing_builds_to_merge=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"require_passing_builds_to_merge\"))")
    if [[ -z ${require_passing_builds_to_merge} ]]; then echo "missing require_passing_builds_to_merge restriction in develop branch"; fi

    require_tasks_to_be_completed=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"require_tasks_to_be_completed\"))")
    if [[ -z ${require_tasks_to_be_completed} ]]; then echo "missing require_tasks_to_be_completed restriction in develop branch"; fi

    reset_pullrequest_approvals_on_change=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"reset_pullrequest_approvals_on_change\"))")
    if [[ -z ${reset_pullrequest_approvals_on_change} ]]; then echo "missing reset_pullrequest_approvals_on_change restriction in develop branch"; fi

    enforce_merge_checks=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"enforce_merge_checks\"))")
    if [[ -z ${enforce_merge_checks} ]]; then echo "missing enforce_merge_checks restriction in develop branch"; fi

    restrict_merges=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"restrict_merges\"))")
    if [[ -z ${restrict_merges} ]]; then echo "missing restrict_merges restriction in develop branch"; fi

    push=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"push\"))")
    if [[ -z ${push} ]]; then echo "missing push restriction in develop branch"; fi

    force=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"force\"))")
    if [[ -z ${force} ]]; then echo "missing force restriction in develop branch"; fi

    delete=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"develop\") and (.kind == \"delete\"))")
    if [[ -z ${delete} ]]; then echo "missing delete restriction in develop branch"; fi

    master_force=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"master\") and (.kind == \"force\"))")
    if [[ -z ${master_force} ]]; then echo "missing force restriction in master branch"; fi

    master_delete=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"master\") and (.kind == \"delete\"))")
    if [[ -z ${master_delete} ]]; then echo "missing delete restriction in master branch"; fi

    master_push=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"master\") and (.kind == \"push\"))")
    if [[ -z ${master_push} ]]; then echo "missing push restriction in master branch"; fi

    master_restrict_merges=$(echo $branch_restrictions | jq -r ".values[] | select((.pattern == \"master\") and (.kind == \"restrict_merges\"))")
    if [[ -z ${master_restrict_merges} ]]; then echo "missing restrict_merges restriction in master branch"; fi
  fi
done;
