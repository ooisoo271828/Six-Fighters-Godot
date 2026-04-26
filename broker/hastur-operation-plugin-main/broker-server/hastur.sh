#!/bin/bash
# Hastur CLI - Godot Editor Remote Execution Tool
# Usage: ./hastur.sh <command> [options]

TOKEN="${HASTUR_TOKEN:-995e7c3f6fabc40a1bcd8a6f94dcad0106959c26c5827d2d3b261e1969109bd7}"
HOST="${HASTUR_HOST:-localhost}"
PORT="${HASTUR_PORT:-5302}"

CMD="${1:-health}"
CODE=""
EXECUTOR_ID=""
PROJECT_NAME=""
TIMEOUT=30000

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        exec)
            CMD="exec"
            shift
            CODE="$1"
            shift
            ;;
        -e|--executor-id)
            EXECUTOR_ID="$2"
            shift 2
            ;;
        -p|--project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        health|executors)
            CMD="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

API_CALL() {
    local endpoint="$1"
    local method="${2:-GET}"
    local body="$3"

    if [ -z "$body" ]; then
        curl -s -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            "http://${HOST}:${PORT}${endpoint}"
    else
        curl -s -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$body" \
            "http://${HOST}:${PORT}${endpoint}"
    fi
}

case "$CMD" in
    health)
        echo -e "\033[1;36mChecking broker health...\033[0m"
        result=$(API_CALL "/api/health")
        echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
        ;;

    executors)
        echo -e "\033[1;36mListing executors...\033[0m"
        result=$(API_CALL "/api/executors")
        echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
        ;;

    exec)
        if [ -z "$CODE" ]; then
            echo -e "\033[1;31mError: Code required for exec command\033[0m"
            echo "Usage: hastur.sh exec 'print(42)' -e <executor-id>"
            exit 1
        fi

        if [ -z "$EXECUTOR_ID" ] && [ -z "$PROJECT_NAME" ]; then
            echo -e "\033[1;31mError: Either -e <executor-id> or -p <project-name> required\033[0m"
            exit 1
        fi

        echo -e "\033[1;36mExecuting...\033[0m"
        echo -e "Code: \033[2m$CODE\033[0m"
        echo ""

        BODY="{\"code\": $(echo "$CODE" | jq -Rs .), \"timeout_ms\": $TIMEOUT}"
        if [ -n "$EXECUTOR_ID" ]; then
            BODY=$(echo "$BODY" | jq --arg id "$EXECUTOR_ID" '. + {executor_id: $id}')
        else
            BODY=$(echo "$BODY" | jq --arg name "$PROJECT_NAME" '. + {project_name: $name}')
        fi

        result=$(API_CALL "/api/execute" "POST" "$BODY")
        echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
        ;;
esac
