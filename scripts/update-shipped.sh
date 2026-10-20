#!/usr/bin/env bash
# Rewrites the "Recently merged upstream" table in README.md with the latest
# merged pull requests to repositories this account does not own.
set -euo pipefail

USER_NAME="${PROFILE_USER:-crimsondhaks}"
# Client work stays off the public profile.
EXCLUDE_OWNERS='["OneDot-Communications"]'
LIMIT=5

rows=$(gh api -X GET search/issues \
  -f q="is:pr author:${USER_NAME} is:merged -user:${USER_NAME}" \
  -f sort=updated -f per_page=50 \
  --jq "[.items[]
         | {repo: (.repository_url | sub(\".*/repos/\"; \"\")),
            title, url: .html_url, number, merged: .pull_request.merged_at}
         | select((.repo | split(\"/\")[0]) as \$o | ${EXCLUDE_OWNERS} | index(\$o) | not)]
        | sort_by(.merged) | reverse | .[:${LIMIT}][]
        | \"| **\(.repo)** | [\(.title | gsub(\"\\\\|\"; \"\\\\|\"))](\(.url)) | \(.merged[0:10]) |\"")

if [ -z "$rows" ]; then
  echo "No merged upstream PRs found; leaving README unchanged."
  exit 0
fi

table=$(printf '| Project | Pull request | Merged |\n| --- | --- | --- |\n%s\n' "$rows")

TABLE="$table" python3 - <<'PY'
import os, re, pathlib
readme = pathlib.Path("README.md")
text = readme.read_text()
start, end = "<!-- shipped:start -->", "<!-- shipped:end -->"
if start not in text or end not in text:
    raise SystemExit("shipped markers missing from README.md")
block = f"{start}\n{os.environ['TABLE']}\n{end}"
readme.write_text(re.sub(re.escape(start) + r".*?" + re.escape(end), lambda _: block, text, flags=re.S))
PY
