#!/usr/bin/env bash

set -u

workspace=${GITHUB_WORKSPACE:-}
if [ -z "$workspace" ] || [ ! -d "$workspace" ]; then
  printf 'GITHUB_WORKSPACE must name an existing caller repository\n' >&2
  exit 2
fi

violations=0

check_file() {
  file=$1
  require_permissions=$2

  if ! grep -n '^' "$file" | awk -v file="$file" -v require_permissions="$require_permissions" '
    function report(line, message) {
      printf "%s:%d: %s\n", file, line, message > "/dev/stderr"
      invalid = 1
    }

    {
      line_number = $0
      sub(/:.*/, "", line_number)
      line = $0
      sub(/^[0-9]+:/, "", line)
      sub(/[[:space:]]*#.*/, "", line)
      sub(/[[:space:]]+$/, "", line)

      if (line ~ /^permissions:[[:space:]]*/) {
        has_permissions = 1
      }

      if (index(line, "actions/checkout") > 0) {
        has_checkout = 1
        checkout_line = line_number
      }

      if (line ~ /^[[:space:]]*persist-credentials:[[:space:]]*[\042\047]?false[\042\047]?[[:space:]]*$/) {
        has_persist_credentials_false = 1
      }

      if (line ~ /^[[:space:]-]*uses:[[:space:]]*/) {
        action = line
        sub(/^[[:space:]-]*uses:[[:space:]]*/, "", action)
        sub(/^[\042\047]/, "", action)
        sub(/[\042\047]$/, "", action)

        if (action !~ /^\.\//) {
          at = index(action, "@")
          ref = substr(action, at + 1)
          if (at == 0 || length(ref) != 40 || ref !~ /^[0-9A-Fa-f]+$/) {
            report(line_number, "external uses ref must be a 40-character hexadecimal SHA")
          }
        }
      }
    }

    END {
      if (require_permissions == "1" && !has_permissions) {
        report(1, "missing top-level permissions declaration")
      }
      if (has_checkout && !has_persist_credentials_false) {
        report(checkout_line, "actions/checkout requires persist-credentials: false")
      }
      exit invalid
    }
  '; then
    violations=1
  fi
}

for directory in "$workspace/.github/workflows" "$workspace/.github/actions"; do
  [ -d "$directory" ] || continue

  while IFS= read -r -d '' file; do
    case $file in
      "$workspace/.github/workflows"/*)
        check_file "$file" 1
        ;;
      *)
        check_file "$file" 0
        ;;
    esac
  done < <(find "$directory" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)
done

if [ "$violations" -ne 0 ]; then
  exit 1
fi

printf 'GitHub Actions hardening contract passed\n'
