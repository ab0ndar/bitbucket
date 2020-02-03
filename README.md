# Bitbucket automation

This is a set of Unix-shell bash scripts designed to automate the recurrent operations 
over Git repositories grouped into a Bitbucket project.   

When you involved in DevOps of a microservices-based product you may face with the necessity to make 
changes to multiple git repositories. Most common example is setting a git tag at the end of a Scrum sprint. 
In case, your repositories are hosted on a Bitbucket you can make multi-repository changes even without cloning them to your local storage.     

Instead of performing a series of git commands, like clone, commit and push, these scripts utilize the [Bitbucket API v2](https://developer.atlassian.com/bitbucket/api/2/reference/).
Thus, all the actions are performed remotely on a Bitbucket servers. 
All the API calls are made with the help of a [curl](https://en.wikipedia.org/wiki/CURL) command and 
the responses are parsed with [jq](https://stedolan.github.io/jq/). 
