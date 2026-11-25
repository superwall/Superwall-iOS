#!/bin/bash
# Runs after Claude Code opens a pull request. If part of the session ran below
# the bar set here, it posts one warning comment on the pull request. It never
# blocks anything, and stays silent when it can't tell what was used. Only members
# of the team's GitHub organization get the comment.

TEAM_ORG="superwall"
BAR="Fable 5.2 on high effort"
PASSING_FAMILIES="fable|mythos"
MIN_VERSION=502 # 5.2, as major * 100 + minor
PASSING_EFFORTS="high|xhigh|max"
MARKER="<!-- claude-model-check -->"

command -v jq > /dev/null || exit 0
command -v gh > /dev/null || exit 0

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<< "$input")

if [ "$tool" = "Bash" ]; then
  command=$(jq -r '.tool_input.command // empty' <<< "$input")
  if ! grep -qE '(^|[^[:alnum:]_-])gh[[:space:]]([^|;&]*[[:space:]])?pr[[:space:]]+(create|new)' <<< "$command"; then
    exit 0
  fi
fi

urls=$(jq -r '.tool_response | tostring' <<< "$input" \
  | grep -oE 'https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/[0-9]+' \
  | awk '!seen[$0]++' \
  | tail -5)
if [ -z "$urls" ]; then
  exit 0
fi

# One line per model reply in the main session: how many, which model, which effort.
transcript=$(jq -r '.transcript_path // empty' <<< "$input")
if [ ! -r "$transcript" ]; then
  exit 0
fi
tally=$(jq -rR '
  fromjson?
  | select(.type == "assistant" and .isSidechain != true)
  | select((.message.model // "") | startswith("claude-"))
  | [.message.id, .message.model, (.effort | if type == "string" then . else "unknown" end)]
  | @tsv' "$transcript" 2> /dev/null | sort -u | cut -f 2,3 | sort | uniq -c)
if [ -z "$tally" ]; then
  exit 0
fi

model_pattern="^claude-($PASSING_FAMILIES)-([0-9]+)(-([0-9]{1,2}))?(\$|[^0-9])"
effort_pattern="^($PASSING_EFFORTS)\$"
total=0
below_total=0
below_rows=()
while read -r count model effort; do
  total=$((total + count))
  passes=1
  if [[ $model =~ $model_pattern ]]; then
    version=$((10#${BASH_REMATCH[2]} * 100 + 10#${BASH_REMATCH[4]:-0}))
    if [ "$version" -lt "$MIN_VERSION" ]; then
      passes=0
    fi
  else
    passes=0
  fi
  if [ "$effort" != "unknown" ] && ! [[ $effort =~ $effort_pattern ]]; then
    passes=0
  fi
  if [ "$passes" -eq 0 ]; then
    below_total=$((below_total + count))
    below_rows+=("$count $model $effort")
  fi
done <<< "$tally"

if [ "$below_total" -eq 0 ]; then
  exit 0
fi

table=""
for row in "${below_rows[@]}"; do
  read -r count model effort <<< "$row"
  share=$((count * 100 / total))
  if [ "$share" -eq 0 ]; then
    share="under 1"
  fi
  table+="| \`$model\` | $effort | $share% |"$'\n'
done

body="> [!WARNING]
> **Model check:** part of the Claude Code session that opened this pull request ran below this repo's bar of $BAR.

| Model | Effort | Share of the session |
|---|---|---|
$table
Give this one a closer review, or redo the work with $BAR or above.

$MARKER"

# True for a pull request the signed-in user opened in the last ten minutes that
# has no warning yet, when that user is in the team's organization. The output
# can link other pull requests, so each is checked.
needs_warning() {
  gh api graphql -f url="$1" -f org="$TEAM_ORG" -f query='
    query($url: URI!, $org: String!) {
      organization(login: $org) { viewerIsAMember }
      resource(url: $url) {
        ... on PullRequest {
          createdAt
          viewerDidAuthor
          comments(last: 100) { nodes { body } }
        }
      }
    }' 2> /dev/null | jq -e --arg marker "$MARKER" '
      .data
      | .organization.viewerIsAMember == true
        and .resource.viewerDidAuthor == true
        and (now - (.resource.createdAt | fromdateiso8601)) < 600
        and (.resource.comments.nodes | all(.body | contains($marker) | not))' > /dev/null 2>&1
}

for url in $urls; do
  if [ -n "$PR_MODEL_CHECK_DRY_RUN" ]; then
    printf '%s\n%s\n' "$url" "$body"
    continue
  fi
  if ! needs_warning "$url"; then
    continue
  fi
  if gh pr comment "$url" --body "$body" > /dev/null 2>&1; then
    jq -n --arg message "Posted a model warning on $url: part of this session ran below $BAR." \
      '{systemMessage: $message}'
  fi
  exit 0
done
exit 0
