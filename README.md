# Bitbucket automation

This is a set of Unix-shell bash scripts designed to automate the recurrent operations 
over Bitbucket/Git repositories grouped into a project.   

When you involved in DevOps of a microservices-based product you may face the necessity to apply the same changes to multiple git repositories. 
Most common scenarios are setting the git tag and merging the branches for all the repositories that have been changed during the Scrum sprint.    
 
Instead of performing a series of git commands, like clone, commit and push, 
scripts from this project utilize the [Bitbucket API v2](https://developer.atlassian.com/bitbucket/api/2/reference/).
Thus, all the actions are performed remotely on a Bitbucket server, without cloning repositories to your local storage. 
The API calls are made with the help of a [curl](https://en.wikipedia.org/wiki/CURL) command and 
the responses are parsed with [jq](https://stedolan.github.io/jq/).  

## Authorization

Every call to the [Bitbucket API v2](https://developer.atlassian.com/bitbucket/api/2/reference/) requires authorization.
Therefore, at first, scripts obtain [OAuth2](https://developer.atlassian.com/cloud/bitbucket/oauth-2/) access token that is used at every subsequent API call.
As it's stated in the [OAuth RFC6749](https://tools.ietf.org/html/rfc6749#section-4), there are four ways to obtain the access token. 
Scripts use [Client Credentials Grant](https://tools.ietf.org/html/rfc6749#section-4.4) type that helps to avoid unwanted interaction with the end-user.  
  
To initiate OAuth2 flow, scripts need client's key and secret.
They have to be created on Bitbucket administrative portal at the OAuth settings page. 
You can get more details on how to create OAuth2 consumer (client's key and secret) from the 
[instruction](https://confluence.atlassian.com/bitbucket/oauth-on-bitbucket-cloud-238027431.html) on the Atlassian web site.
As soon as Bitbucket OAuth2 consumer is created, enable Client Credentials Grant type by checking "This is a private consumer" option and
assign the following permissions to allow scripts to make changes to your repositories:  
 * projects:write  
 * repositories:admin  
 * pull requests:write  

## Set tag

Set git tag to all the repositories of the specified Bitbucket project. 
Or, if repo parameter is present, set git tag to that only repository.

### Parameters
| Name            | Required | Description |
| --------------- | -------- | ------------- |
| client-id       | yes      | Bitbucket OAuth2 consumer's key, has to be created on Bitbucket administrative portal at the OAuth settings page. |
| client-secret   | yes      | Bitbucket OAuth2 consumer's secret, has to be created on Bitbucket administrative portal at the OAuth settings page. |
| workspace       | yes      | Bitbucket workspace ID. The workspace ID is the part in the URL before the repository slug. Usernames and workspace IDs are often the same. |
| project         | yes      | Bitbucket project name.  |
| repo            | no       | Bitbucket/Git repository name. If specified, the git tag is set to that only repository. If omitted, the git tag is set to all the repositories of the specified project. |
| branch          | yes      | Bitbucket/Git branch name. Git tag is set to the latest commit in the specified git branch. |
| tag             | yes      | Git tag value to set.  |
  
### Example
Set tag **v1.3.42** to the latest revision in **master** branch in every repository 
of **MyVeryCoolProject** project belonged to the **ab0ndar** Bitbucket workspace.   
```
./bin/tag-add.sh \  
--client-id bitbucket-oauth2-consumer-key \  
--client-secret "bitbucket-oauth2-consumer-secret" \
--workspace ab0ndar \  
--project MyVeryCoolProject \    
--branch master \  
--tag "v1.3.42"
``` 
 
## Create pull request

Create pull request for all the repositories of the specified Bitbucket project. 
Or, if repo parameter is present, create pull request for that only repository.

### Parameters
| Name            | Required | Description |
| --------------- | -------- | ------------- |
| client-id       | yes      | Bitbucket OAuth2 consumer's key, has to be created on Bitbucket administrative portal at the OAuth settings page. |
| client-secret   | yes      | Bitbucket OAuth2 consumer's secret, has to be created on Bitbucket administrative portal at the OAuth settings page. |
| workspace       | yes      | Bitbucket workspace ID. The workspace ID is the part in the URL before the repository slug. Usernames and workspace IDs are often the same. |
| project         | yes      | Bitbucket project name.  |
| repo            | no       | Bitbucket/Git repository name. If specified, the git tag is set to that only repository. If omitted, the git tag is set to all the repositories of the specified project. |
| branch-src      | yes      | Bitbucket/Git source branch name.  |
| branch-dst      | yes      | Bitbucket/Git destination branch name.  |
  
### Example
Create pull requests for merging **master** branches to **develop** in every repository 
of **MyVeryCoolProject** project belonged to the **ab0ndar** Bitbucket workspace.   
```
./bin/pr-create.sh \  
--client-id bitbucket-oauth2-consumer-key \  
--client-secret "bitbucket-oauth2-consumer-secret" \
--workspace ab0ndar \  
--project MyVeryCoolProject \    
--branch-src develop \  
--branch-dst master
```  
