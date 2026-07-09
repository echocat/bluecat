#!/usr/bin/env bash

retry() {
  local attempt max_attempts delay
  max_attempts=5
  delay=10

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if "$@"; then
      return 0
    fi

    if ((attempt == max_attempts)); then
      return 1
    fi

    echo "    attempt ${attempt}/${max_attempts} failed; retrying in ${delay}s..."
    sleep "${delay}"
    delay=$((delay * 2))
  done
}
