#!/usr/bin/env bash

set -u

test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
action_dir=$(CDPATH= cd -- "$test_dir/../../.github/actions/workflow-contract" && pwd)

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

valid_output=$(GITHUB_WORKSPACE="$test_dir/fixtures/valid" bash "$action_dir/check.sh" 2>&1) || {
  printf '%s\n' "$valid_output" >&2
  fail 'valid fixture was rejected'
}
printf '%s\n' "$valid_output" | grep -F 'GitHub Actions hardening contract passed' >/dev/null || \
  fail 'valid fixture did not report success'

if invalid_output=$(GITHUB_WORKSPACE="$test_dir/fixtures/invalid" bash "$action_dir/check.sh" 2>&1); then
  printf '%s\n' "$invalid_output" >&2
  fail 'invalid fixture was accepted'
fi

printf '%s\n' "$invalid_output" | grep -F 'invalid.yml' >/dev/null || \
  fail 'invalid fixture output did not identify the violating file'

if unrelated_output=$(GITHUB_WORKSPACE="$test_dir/fixtures/unrelated-persist" bash "$action_dir/check.sh" 2>&1); then
  printf '%s\n' "$unrelated_output" >&2
  fail 'unrelated persist-credentials setting was accepted'
fi

printf '%s\n' "$unrelated_output" | grep -F 'unrelated.yml:12: actions/checkout requires persist-credentials: false' >/dev/null || \
  fail 'unrelated persist-credentials output did not identify the checkout line'

printf 'workflow-contract tests passed\n'
