# wooto shared workflows

This repository provides reusable GitHub Actions checks for wooto repositories.

## Workflow lint

Add this caller workflow as `.github/workflows/workflow-lint.yml`:

```yaml
name: Shared workflow lint
on:
  pull_request:
    paths:
      - .github/workflows/**
      - .github/actions/**
  push:
    branches: [main]
    paths:
      - .github/workflows/**
      - .github/actions/**
permissions:
  contents: read
jobs:
  lint:
    uses: wooto/shared-workflows/.github/workflows/workflow-lint.yml@58879bbcc2f6c692ef799b03f40dd32ab987c0ad
```

The caller must declare `permissions: contents: read`. Do not use
`secrets: inherit`; this reusable workflow does not accept or need caller
secrets.

The reusable workflow checks the caller repository with actionlint, zizmor,
and the shared workflow contract. It automatically reads
`.github/actionlint.yaml` when that file exists. Repositories with custom
self-hosted runner labels should declare them as actionlint glob patterns:

```yaml
self-hosted-runner:
  labels:
    - wooto-*
```

Pin the reusable workflow and every direct external action reference to a
40-character commit SHA. Do not use branches or tags as action references.
Update the caller pin deliberately when adopting a newer shared workflow
commit.
