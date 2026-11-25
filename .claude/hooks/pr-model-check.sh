#!/bin/bash
# Runs after Claude Code opens a pull request. If part of the work on it ran
# below the bar set here, it posts one warning comment on the pull request. It
# never blocks anything, and stays silent when it can't tell what was used. Only
# members of the team's GitHub organization get the comment.
#
# Only the work on that pull request counts: the replies since the session last
# opened another pull request that read or changed one of this one's files. Chat
# and earlier pull requests in the same session are left out.

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

# A shell command that opens a pull request.
OPENS_PR='(^|[^[:alnum:]_-])gh[[:space:]]([^|;&]*[[:space:]])?pr[[:space:]]+(create|new)'

if [ "$tool" = "Bash" ]; then
  command=$(jq -r '.tool_input.command // empty' <<< "$input")
  if ! grep -qE "$OPENS_PR" <<< "$command"; then
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

transcript=$(jq -r '.transcript_path // empty' <<< "$input")
if [ ! -r "$transcript" ]; then
  exit 0
fi

# One line per model reply that worked on the pull request at $1: how many,
# which model, which effort.
#
# Work on it starts after the last other pull request this session opened. Of
# the replies since, only those that read or changed one of its files count. If
# none of them can be tied to a file, all of them count.
tally_for() {
  local number files
  number=${1##*/}
  files=$(gh pr view "$1" --json files --jq '[.files[].path]' 2> /dev/null)
  if ! jq -e 'type == "array"' <<< "$files" > /dev/null 2>&1; then
    files='[]'
  fi
  jq -rnR --arg number "$number" --arg opens_pr "$OPENS_PR" --argjson files "$files" '
    def tool_uses: [.message.content | arrays | .[] | select(.type == "tool_use")];
    def opens_pr:
      (.name == "Bash" and ((.input.command // "") | test($opens_pr)))
      or ((.name // "") | test("pull_request_create|create_pull_request"));
    [inputs | fromjson? | select(.isSidechain != true)] as $lines
    | [$lines[] | select(.type == "user") | .message.content | arrays | .[]
        | select(.type == "tool_result")
        | (tostring) as $result
        | select(($result | test("github\\.com/[^/ ]+/[^/ ]+/pull/[0-9]+"))
            and ($result | test("/pull/" + $number + "([^0-9]|$)") | not))
        | .tool_use_id] as $opened_another
    | ([$lines | to_entries[]
        | select(.value.type == "assistant")
        | select(any(.value | tool_uses[]; opens_pr and (.id as $id | $opened_another | index($id) != null)))
        | .key] | max // -1) as $start
    | [$lines | to_entries[]
        | select(.key > $start and .value.type == "assistant")
        | .value
        | select((.message.model // "") | startswith("claude-"))] as $replies
    | [$replies[]
        | select(any(tool_uses[]; (.input | tostring) as $call | any($files[]; . as $file | $call | contains($file))))
      ] as $on_files
    | (if ($on_files | length) > 0 then $on_files else $replies end)
    | map([.message.id, .message.model, (.effort | if type == "string" then . else "unknown" end)])
    | unique | .[] | .[1:] | @tsv' "$transcript" 2> /dev/null | sort | uniq -c
}

model_pattern="^claude-($PASSING_FAMILIES)-([0-9]+)(-([0-9]{1,2}))?(\$|[^0-9])"
effort_pattern="^($PASSING_EFFORTS)\$"

# Sets $body to the warning for the pull request at $1, or fails if the work on
# it met the bar or can't be told.
warning_for() {
  local tally total below_total below_rows count model effort passes version share table row
  tally=$(tally_for "$1")
  if [ -z "$tally" ]; then
    return 1
  fi
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
    return 1
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
> **Model check:** part of the work on this pull request ran below this repo's bar of $BAR.

| Model | Effort | Share of the work |
|---|---|---|
$table
Don't you be token-keeping now, switch to $BAR or above and run a code review.

$MARKER"
}

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
    if warning_for "$url"; then
      printf '%s\n%s\n' "$url" "$body"
    else
      printf '%s\nno warning\n' "$url"
    fi
    continue
  fi
  if ! needs_warning "$url"; then
    continue
  fi
  if ! warning_for "$url"; then
    exit 0
  fi
  if gh pr comment "$url" --body "$body" > /dev/null 2>&1; then
    jq -n --arg message "Posted a model warning on $url: part of the work on it ran below $BAR." \
      '{systemMessage: $message}'
  fi
  exit 0
done
exit 0
