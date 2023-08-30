# README

Dockerfile for running Phorge in a container. Based on: <https://github.com/cooperspencer/phorge>

## Differences from the original Dockerfile

- Use debian 12 (bookworm)
- Remove ssh server support
- Fetch Phorge commits by sha instead of downloading the latest one at build time
- Add mysql configuration as per Phorge suggestions
