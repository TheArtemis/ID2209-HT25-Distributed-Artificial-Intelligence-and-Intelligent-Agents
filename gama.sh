#!/usr/bin/env bash
set -euo pipefail

# Resolve the directory of this script (works when sourced or executed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Look for a .env file one level up from the script and source it if present.
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
	# shellcheck disable=SC1090
	source "$ENV_FILE"
fi

# Require GAMA_EXEC_PATH to be set either in the .env file or in the environment.
if [ -z "${GAMA_EXEC_PATH-}" ]; then
	echo "Error: GAMA_EXEC_PATH is not set. Please set it in $ENV_FILE or export it in your environment." >&2
	exit 2
fi

# Exec the GAMA executable with all passed arguments
exec "$GAMA_EXEC_PATH" "$@"