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

    function indentation(value, prefix) {
      prefix = value
      sub(/[^[:space:]].*$/, "", prefix)
      return length(prefix)
    }

    function check_checkout() {
      if (checkout_line && !checkout_has_persist_credentials_false) {
        report(checkout_line, "actions/checkout requires persist-credentials: false")
      }
      checkout_line = 0
      checkout_with_indent = -1
      checkout_with_child_indent = -1
    }

    {
      line_number = $0
      sub(/:.*/, "", line_number)
      line = $0
      sub(/^[0-9]+:/, "", line)
      sub(/[[:space:]]*#.*/, "", line)
      sub(/[[:space:]]+$/, "", line)
      indent = indentation(line)

      if (line ~ /^[[:space:]]*-[[:space:]]/) {
        if (checkout_line && indent <= checkout_step_indent) {
          check_checkout()
        }
        step_indent = indent
      }

      if (checkout_line && checkout_with_indent >= 0 && line !~ /^[[:space:]]*$/ && indent <= checkout_with_indent) {
        checkout_with_indent = -1
        checkout_with_child_indent = -1
      }

      if (line ~ /^permissions:[[:space:]]*/) {
        has_permissions = 1
      }

      if (checkout_line && line ~ /^[[:space:]]*with:[[:space:]]*$/ && indent == checkout_key_indent) {
        checkout_with_indent = indent
        checkout_with_child_indent = -1
      }

      if (checkout_line && checkout_with_indent >= 0 && line !~ /^[[:space:]]*$/ && indent > checkout_with_indent) {
        if (checkout_with_child_indent < 0) {
          checkout_with_child_indent = indent
        }
        if (indent == checkout_with_child_indent && line ~ /^[[:space:]]*persist-credentials:[[:space:]]*[\042\047]?false[\042\047]?[[:space:]]*$/) {
          checkout_has_persist_credentials_false = 1
        }
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

        if (action ~ /^actions\/checkout@/) {
          if (checkout_line) {
            check_checkout()
          }
          checkout_line = line_number
          checkout_step_indent = step_indent
          checkout_key_indent = indent
          if (line ~ /^[[:space:]]*-[[:space:]]+uses:[[:space:]]*/) {
            checkout_key_indent += 2
          }
          checkout_with_indent = -1
          checkout_with_child_indent = -1
          checkout_has_persist_credentials_false = 0
        }
      }
    }

    END {
      if (require_permissions == "1" && !has_permissions) {
        report(1, "missing top-level permissions declaration")
      }
      check_checkout()
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
