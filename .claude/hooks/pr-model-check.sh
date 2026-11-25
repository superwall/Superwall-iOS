#!/bin/bash
# Runs after Claude Code opens a pull request. If part of the work on it ran
# below the bar set here, it posts one warning comment on the pull request. It
# never blocks anything, and stays silent when it can't tell what was used. Only
# members of the team's GitHub organization get the comment.
#
# Only the work on that pull request counts: the replies that read or changed
# one of its files. Work on a file from before the session opened another pull
# request with that file in it belongs to that one, and is left out. So is chat.

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
# The same, for a line of an earlier command in the session log. Stricter, so a
# command that only mentions one in a string isn't taken for one.
OPENED_PR='^\s*(.*(&&|\|\||[;|(]|\$\()\s*)?([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*gh\s+([^|;&]*\s)?pr\s+(create|new)(\s|$)'
# How many of the session's earlier pull requests are looked up.
MAX_EARLIER=8

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

# The paths the pull request at $1 changes, as a JSON array. Fails if they can't
# be read.
files_of() {
  local path repo number names
  path=${1#https://github.com/}
  repo=${path%/pull/*}
  number=${path##*/}
  names=$(gh api "repos/$repo/pulls/$number/files?per_page=100" --paginate \
    --jq '.[] | .filename, (.previous_filename // empty)' 2> /dev/null) || return 1
  jq -Rn '[inputs | select(length > 0)]' <<< "$names"
}

# The pull requests this session opened: the log line each was opened on, and
# its link. A command only counts if it ran `gh pr create` and printed a pull
# request's link on a line of its own, or was a pull request tool. One that says
# the pull request already exists didn't open it.
earlier_pull_requests() {
  jq -rnR --arg opened_pr "$OPENED_PR" '
    def text:
      if type == "string" then .
      elif type == "array" then [.[] | objects | .text // empty] | join("\n")
      else "" end;
    [inputs | fromjson? | select(type == "object") | select(.isSidechain != true)] as $lines
    | ([$lines[] | select(.type == "user") | .message.content | arrays | .[] | objects
        | select(.type == "tool_result" and .is_error != true and (.tool_use_id | type == "string"))
        | {key: .tool_use_id, value: (.content | text)}] | from_entries) as $results
    | $lines | to_entries[] | select(.value.type == "assistant") | .key as $index
    | .value.message.content | arrays | .[] | objects | select(.type == "tool_use")
    | ($results[.id // ""] // "") as $result
    | select($result | test("already exists") | not)
    | (if .name == "Bash" and ((.input.command // "") | split("\n") | any(test($opened_pr))) then
        [$result | split("\n")[]
          | select(test("^\\s*https://github\\.com/[^/\\s]+/[^/\\s]+/pull/[0-9]+\\s*$"))
          | gsub("\\s"; "")] | unique[]
      elif ((.name // "") | test("pull_request_create|create_pull_request")) then
        [$result | match("https://github\\.com/[^/\\s\"\\\\]+/[^/\\s\"\\\\]+/pull/[0-9]+"; "g").string] | first // empty
      else empty end)
    | [$index, .] | @tsv' "$transcript" 2> /dev/null
}

# Looks up the session's earlier pull requests once, for every link checked.
# Sets $earlier to [{start, url, files}] for the latest $MAX_EARLIER, and
# $floor to the log line of the newest one left out for being older, or -1.
# A link whose files can't be read is left out.
earlier=""
floor=-1
load_earlier() {
  local all total index url files
  if [ -n "$earlier" ]; then
    return
  fi
  earlier='[]'
  all=$(earlier_pull_requests)
  if [ -z "$all" ]; then
    return
  fi
  total=$(grep -c . <<< "$all")
  if [ "$total" -gt "$MAX_EARLIER" ]; then
    floor=$(sed -n "$((total - MAX_EARLIER))p" <<< "$all" | cut -f 1)
  fi
  while read -r index url; do
    if [ -z "$url" ]; then
      continue
    fi
    files=$(files_of "$url") || continue
    earlier=$(jq -c --argjson start "$index" --arg url "$url" --argjson files "$files" \
      '. + [{start: $start, url: $url, files: $files}]' <<< "$earlier")
  done < <(tail -n "$MAX_EARLIER" <<< "$all")
}

lowercased() {
  tr '[:upper:]' '[:lower:]' <<< "$1"
}

# One line per model reply that worked on the pull request at $1: how many,
# which model, which effort.
#
# A reply worked on it if one of its tool calls names one of the pull request's
# files. Work on a file from before the session opened another pull request with
# a file of that name in it isn't counted, nor is work from before the earlier
# pull requests that weren't looked up. If no reply can be tied to a file, the
# replies since the last other pull request count.
tally_for() {
  local files others
  files=$(files_of "$1") || files='[]'
  load_earlier
  others=$(jq -c --arg url "$(lowercased "$1")" \
    '[.[] | select((.url | ascii_downcase) != $url)]' <<< "$earlier")

  jq -rnR --argjson files "$files" --argjson others "$others" --argjson floor "$floor" '
    def name: split("/") | last;
    def tool_calls:
      [.message.content | arrays | .[] | objects | select(.type == "tool_use") | .input | .. | strings]
      | join("\n");
    # Whether the text names the file, and not just a longer name ending in it.
    def names($name):
      contains($name)
      and test("(^|[^A-Za-z0-9_.+-])"
        + ($name | gsub("(?<c>[\\\\.^$|?*+()\\[\\]{}])"; "\\\(.c)"))
        + "($|[^A-Za-z0-9_])");
    [inputs | fromjson? | select(type == "object") | select(.isSidechain != true)] as $lines
    | ([$floor] + ($others | map(.start)) | max) as $last_other
    | ($files | map(name) | unique | map(. as $name | {
        key: $name,
        value: ([$floor] + [$others[] | select(any(.files[]; name == $name)) | .start] | max)
      }) | from_entries) as $work_starts
    | [$lines | to_entries[]
        | select(.value.type == "assistant")
        | select((.value.message.model // "") | startswith("claude-"))] as $replies
    | [$replies[]
        | .key as $index
        | (.value | tool_calls) as $calls
        | select(any($work_starts | to_entries[]; $index > .value and (.key as $name | $calls | names($name))))
        | .value] as $on_files
    | (if ($on_files | length) > 0 then $on_files
       else [$replies[] | select(.key > $last_other) | .value] end)
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

posted=()
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
    continue
  fi
  if gh pr comment "$url" --body "$body" > /dev/null 2>&1; then
    posted+=("$url")
  fi
done
if [ "${#posted[@]}" -gt 0 ]; then
  jq -n --arg message "Posted a model warning on ${posted[*]}: part of the work ran below $BAR." \
    '{systemMessage: $message}'
fi
exit 0
