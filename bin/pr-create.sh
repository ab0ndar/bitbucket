#!/usr/bin/env bash

# Bitbucket API Documentation: https://developer.atlassian.com/bitbucket/api/2/reference/

function print_help {
echo -e "Create pull request

Required parameters:
    --client-id|BITBUCKET_CLIENT_ID - Bitbucket OAuth consumer key
    --client-secret|BITBUCKET_CLIENT_SECRET - Bitbucket OAuth consumer secret
    --workspace|BITBUCKET_WORKSPACE - Bitbucket workspace
    --project|BITBUCKET_PROJECT - Bitbucket project
    --branch-src|BITBUCKET_BRANCH_SRC - PR source Bitbucket/git branch
    --branch-dst|BITBUCKET_BRANCH_DST - PR destination Bitbucket/git branch

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
    --branch-src)
    BITBUCKET_BRANCH_SRC="$2"
    shift # past argument
    shift # past value
    ;;
    --branch-dst)
    BITBUCKET_BRANCH_DST="$2"
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
if [[ -z ${BITBUCKET_BRANCH_SRC} ]]; then echo "--branch-src is required"; exit 1; fi
if [[ -z ${BITBUCKET_BRANCH_DST} ]]; then echo "--branch-dst is required"; exit 1; fi

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
  # Get reference to the ${BITBUCKET_BRANCH_DST}
  hash=$(curl -s -q -X GET -H "Authorization: Bearer ${access_token}" \
         "$repo/refs/branches?q=name+%7E+%22${BITBUCKET_BRANCH_DST}%22" | jq -r ".values[].target.hash")
  if [[ -z ${hash} ]];
  then
    echo "skipped $repo"
  else
    echo $repo
    # Create pull-request from ${BITBUCKET_BRANCH_SRC} to ${BITBUCKET_BRANCH_DST} in the ${repo}
    json="{\"title\": \"Merge from ${BITBUCKET_BRANCH_SRC} to ${BITBUCKET_BRANCH_DST}\",\"source\": {\"branch\": {\"name\": \"${BITBUCKET_BRANCH_SRC}\"}},\"destination\": {\"branch\": {\"name\": \"${BITBUCKET_BRANCH_DST}\"}},\"close_source_branch\": false}"

    response=$(curl -s -X POST -H "Authorization: Bearer ${access_token}" \
                    -H "Content-Type: application/json" -d "${json}" "$repo/pullrequests")
    type=$(echo "${response}" | jq -r ".type")
    if [[ $type = "error" ]]
    then
      echo "${response}" | jq -r ".error.message"
    else
      echo "done"
    fi
  fi
done;
