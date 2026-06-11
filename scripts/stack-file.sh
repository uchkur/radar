#!/usr/bin/env bash
# Выбор compose-файла: M2 (arm64) → Oracle 23 Free; Intel/Linux → Oracle XE 11.
if [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]; then
  echo "docker/podman-network.stack.m2.yml"
else
  echo "docker/podman-network.stack.yml"
fi
