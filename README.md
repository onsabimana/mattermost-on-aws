
# Mattermost deployment on AWS

1. Mattermost deployment - by default to AWS Sydney region.
2. Uses AWS aurora DB
3. Currently running the team version.
4. Uses FARGATE to manage application containers.
5. Haven't tested with a large team - so let us know when you roll it out with hundreds of users.

## Running locally

- `make validate`
- `make plan`
- `make apply`
- `make destroy`
