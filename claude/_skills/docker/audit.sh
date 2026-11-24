#!/usr/bin/env bash
# Read-only. Counts images, containers, volumes and networks per local.lifecycle value
# and lists the unlabelled ones. Unlabelled images with a registry digest are counted as
# pulled (third-party, not ours to label). LIMIT sets how many names are listed (default 40).
set -uo pipefail

LIMIT=${LIMIT:-40}

rows() {
    case $1 in
        image)
            docker image ls -q --no-trunc | sort -u | xargs -r docker image inspect --format \
                '{{if .RepoTags}}{{index .RepoTags 0}}{{else}}{{.Id}}{{end}}|{{index .Config.Labels "local.lifecycle"}}|{{index .Config.Labels "local.repo"}}|{{len .RepoDigests}}' ;;
        container)
            docker ps -a --format '{{.Names}}|{{.Label "local.lifecycle"}}|{{.Label "local.repo"}}' ;;
        volume)
            docker volume ls --format '{{.Name}}|{{.Label "local.lifecycle"}}|{{.Label "local.repo"}}' ;;
        network)
            docker network ls --format '{{.Name}}|{{.Label "local.lifecycle"}}|{{.Label "local.repo"}}' \
                | grep -v -E '^(bridge|host|none)\|' ;;
    esac
}

for kind in image container volume network; do
    out=$(rows "$kind")
    [[ -n $out ]] || { echo "$kind: none"; continue; }
    awk -F'|' -v kind="$kind" -v limit="$LIMIT" '
        { total++ }
        $2 == "state" || $2 == "cache" || $2 == "disposable" { n[$2]++; next }
        $2 == "" && $4 + 0 > 0 { pulled++; next }
        $2 == "" { unl++; if (unl <= limit) names = names " " $1; next }
        { bad++; badnames = badnames " " $1 "=" $2 }
        END {
            printf "%s: %d total, state %d, cache %d, disposable %d, unlabelled %d, invalid %d", \
                kind, total, n["state"], n["cache"], n["disposable"], unl, bad
            if (kind == "image") printf ", pulled %d", pulled
            printf "\n"
            if (unl) printf "  unlabelled:%s%s\n", names, (unl > limit ? " ... (" unl - limit " more)" : "")
            if (bad) printf "  invalid lifecycle:%s\n", badnames
        }' <<<"$out"
done
