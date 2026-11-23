# Security

This repository configures a personal cluster and home network. We publish it to show how we work, so a report that
something here could be used against the cluster, its services or the people who run it is very welcome.

## Reporting a vulnerability

Report it privately through [GitHub's private vulnerability reporting](https://github.com/omelette-gay/coven/security/advisories/new)
(**Security → Report a vulnerability**). Please don't open a public issue or pull request for it.

Useful things to include:

- what you found, and where (file, workflow, or the service and URL)
- how it could be used, and what someone would need to already have to use it
- a secret you think you've found here: say where it is, but don't test whether it works

There's no bug bounty. This is run by two people in their spare time, so replies are best effort, but we read
everything that comes in and fix what matters.

## In scope

- this repository's code, workflows and docs, including anything published here that shouldn't be
- the services it deploys at `*.omelette.gay`, as far as finding a problem doesn't need you to attack them: no
  scanning, load testing, or attempts to log in or get at other people's data

Self-deployed apps that live in their own repositories are run by us too, but report problems in those to the
repository concerned.
