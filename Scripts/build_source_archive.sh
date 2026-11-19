#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
version="GE-v0.12.0-build66"
archive_name="InnerCorners-${version}-source"
output_path="${project_dir}/outputs/${archive_name}.zip"
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/innercorners-source.XXXXXX")"

cleanup() {
    rm -rf -- "${staging_root}"
}
trap cleanup EXIT

mkdir -p "${staging_root}/${archive_name}" "${project_dir}/outputs"

for item in .gitignore Assets Package.swift Packaging README.md Scripts Sources Tests docs; do
    if [[ -e "${project_dir}/${item}" ]]; then
        cp -R "${project_dir}/${item}" "${staging_root}/${archive_name}/"
    fi
done

xattr -cr "${staging_root}/${archive_name}"
find "${staging_root}/${archive_name}" -name '.DS_Store' -delete
find "${staging_root}/${archive_name}" -name '._*' -delete

rm -f -- "${output_path}"
(
    cd "${staging_root}"
    /usr/bin/zip -q -r -X "${output_path}" "${archive_name}"
)

echo "Created ${output_path}"
shasum -a 256 "${output_path}"
