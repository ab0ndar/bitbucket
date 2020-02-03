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
