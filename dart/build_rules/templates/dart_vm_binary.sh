#!/bin/bash
set -e

# All sources are resolved relative to $RUNFILES.
if [[ -n "$TEST_SRCDIR" && -d "$TEST_SRCDIR" ]]; then
  # use $TEST_SRCDIR if set.
  export RUNFILES="$TEST_SRCDIR"
elif [[ -z "$RUNFILES" ]]; then
  # canonicalize the entrypoint.
  pushd "$(dirname "$0")" > /dev/null
  abs_entrypoint="$(pwd -P)/$(basename "$0")"
  popd > /dev/null
  if [[ -e "${abs_entrypoint}.runfiles" ]]; then
    # runfiles dir found alongside entrypoint.
    export RUNFILES="${abs_entrypoint}.runfiles"
  elif [[ "$abs_entrypoint" == *".runfiles/"* ]]; then
    # runfiles dir found in entrypoint path.
    export RUNFILES="${abs_entrypoint%.runfiles/*}.runfiles"
  else
    # runfiles dir not found: fall back on current directory.
    export RUNFILES="$PWD"
  fi
fi
export BAZEL_WORKSPACE_NAME="%workspace%"
dart="$RUNFILES/%dart_vm%"
package_spec="$RUNFILES/%package_spec%"
script_file="$RUNFILES/%script_file%"
"$dart" --packages="$package_spec" %vm_flags% "$script_file" %script_args% "$@"
