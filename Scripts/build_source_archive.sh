#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="v0.11.0-rc.7"
archive_name="InnerCorners-${version}-source"
output_path="${project_dir}/outputs/${archive_name}.zip"
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/innercorners-source.XXXXXX")"

cleanup() {
    rm -rf -- "${staging_root}"
}
trap cleanup EXIT

mkdir -p "${staging_root}/${archive_name}"
git -C "${project_dir}" archive HEAD | tar -x -C "${staging_root}/${archive_name}"
rm -rf -- "${staging_root}/${archive_name}/outputs"

mkdir -p "${staging_root}/${archive_name}/docs"
cp "${project_dir}/outputs/InnerCorners_GitHub公開・機能拡張計画.md" \
   "${staging_root}/${archive_name}/docs/ROADMAP.md"
cp "${project_dir}/outputs/InnerCorners_OS別ホットコーナーアクション調査.md" \
   "${staging_root}/${archive_name}/docs/HOT_CORNER_SURVEY.md"

rm -f -- "${output_path}"
(
    cd "${staging_root}"
    /usr/bin/zip -q -r -X "${output_path}" "${archive_name}"
)

echo "Created ${output_path}"
