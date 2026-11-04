#!/bin/bash
set -euo pipefail

SOURCE_DIR="${1:?Usage: generate-release-notes.sh SOURCE_DIR OWNER/REPO SOURCE_REF}"
SOURCE_REPO="${2:?Source repository is required}"
SOURCE_REF="${3:?Source ref is required}"
SOURCE_URL="https://github.com/$SOURCE_REPO"
SOURCE_SHA=$(git -C "$SOURCE_DIR" rev-parse HEAD)
SOURCE_TAG=""
NOTES=""

TAGS=$(git -C "$SOURCE_DIR" tag --points-at "$SOURCE_SHA" --sort=-version:refname)
if [ -n "$TAGS" ]; then
  SOURCE_TAG=$(printf '%s\n' "$TAGS" | head -n 1)
  if printf '%s\n' "$TAGS" | grep -Fxq -- "$SOURCE_REF"; then
    SOURCE_TAG="$SOURCE_REF"
  fi

  # Listing releases avoids treating authentication/network errors as a missing release.
  NOTES=$(gh api "repos/$SOURCE_REPO/releases" --paginate --slurp |
    jq -r --arg tag "$SOURCE_TAG" '[.[][] | select(.tag_name == $tag) | .body // ""][0] // ""')
fi

if [[ ! "$NOTES" =~ [^[:space:]] ]]; then
  PREVIOUS_TAG=""
  read -r _ PARENT _ <<< "$(git -C "$SOURCE_DIR" rev-list --parents -n 1 "$SOURCE_SHA")"
  if [ -n "$PARENT" ]; then
    PREVIOUS_TAGS=$(git -C "$SOURCE_DIR" tag --merged "$PARENT")
    if [ -n "$PREVIOUS_TAGS" ]; then
      PREVIOUS_TAG=$(git -C "$SOURCE_DIR" describe --tags --abbrev=0 "$PARENT")
    fi
  fi

  RANGE="$SOURCE_SHA"
  if [ -n "$PREVIOUS_TAG" ]; then
    RANGE="$PREVIOUS_TAG..$SOURCE_SHA"
  fi

  printf "## What's Changed\n\n"
  git -C "$SOURCE_DIR" log --format="* %s ([%h]($SOURCE_URL/commit/%H))" "$RANGE"
  if [ -n "$PREVIOUS_TAG" ]; then
    printf '\n**Full Changelog**: %s/compare/%s...%s\n' "$SOURCE_URL" "$PREVIOUS_TAG" "$SOURCE_SHA"
  else
    printf '\n**Full Changelog**: %s/commits/%s\n' "$SOURCE_URL" "$SOURCE_SHA"
  fi
else
  printf '%s\n' "$NOTES"
fi

printf "\n---\nBuilt from [%s](%s) at commit [%s](%s/commit/%s) (ref: \`%s\`).\n" \
  "$SOURCE_REPO" "$SOURCE_URL" "$SOURCE_SHA" "$SOURCE_URL" "$SOURCE_SHA" "$SOURCE_REF"
