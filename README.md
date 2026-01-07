# README

Dockerfile for running Phorge in a container. Based on: <https://github.com/cooperspencer/phorge>

Authentik login provider based on: https://github.com/zhegao9/phabricator-keycloak-extension

## Differences from the original Dockerfile

- Use debian 12 (bookworm)
- Remove ssh server support
- Fetch Phorge commits by sha instead of downloading the latest one at build time
- Add mysql configuration as per Phorge suggestions
