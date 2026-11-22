#!/usr/bin/env bash
# Fails if the Vivado project references source files outside this repository
# (e.g. ~/Micro/rtl added by mistake through "Add Sources").
#
# Usage:
#   scripts/check_xpr.sh              # check build/vivado/mips.xpr on disk
#   scripts/check_xpr.sh --staged     # check the version staged for commit
set -euo pipefail

root=$(git rev-parse --show-toplevel)
xpr_rel=build/vivado/mips.xpr
proj_dir=$root/build/vivado          # $PPRDIR
srcs_dir=$proj_dir/mips.srcs         # $PSRCDIR

if [[ ${1:-} == --staged ]]; then
  content=$(git show ":$xpr_rel" 2>/dev/null) || exit 0
else
  [[ -f $root/$xpr_rel ]] || exit 0
  content=$(cat "$root/$xpr_rel")
fi

bad=()
while IFS= read -r p; do
  [[ -z $p ]] && continue
  resolved=${p//\$PPRDIR/$proj_dir}
  resolved=${resolved//\$PSRCDIR/$srcs_dir}
  resolved=$(realpath -m "$resolved")
  [[ $resolved == "$root"/* ]] || bad+=("$p  ->  $resolved")
done < <(grep -o 'File Path="[^"]*"' <<<"$content" | sed 's/^File Path="//; s/"$//')

if ((${#bad[@]})); then
  echo "ERROR: $xpr_rel references files outside the repository:" >&2
  printf '  %s\n' "${bad[@]}" >&2
  echo "Remove them in Vivado (Sources > Remove File from Project) and add the files from rtl/ instead." >&2
  exit 1
fi
