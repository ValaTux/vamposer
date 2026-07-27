#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_SLUG="vamposer"
REPO_URL="${VALA_TEMPLATE_REPO_URL:-https://github.com/ValaTux/vamposer.git}"
REPO_REF="${VALA_TEMPLATE_REF:-master}"
GITHUB_REPO="${VALA_TEMPLATE_GITHUB_REPO:-ValaTux/vamposer}"

PROJECT_ROOT="${1:-$PWD}"
MESON_FILE="${PROJECT_ROOT}/meson.build"
VAPI_DIR="${PROJECT_ROOT}/vapi"
LIB_DIR="${PROJECT_ROOT}/lib"
INCLUDE_DIR="${PROJECT_ROOT}/include"

START_MARKER="# >>> ${PROJECT_SLUG} local setup >>>"
END_MARKER="# <<< ${PROJECT_SLUG} local setup <<<"

if [ ! -f "${MESON_FILE}" ]; then
    echo -e "${RED}[Error] meson.build not found in ${PROJECT_ROOT}.${NC}"
    echo -e "Run this script in the root of your Meson consumer project, or pass the project path as the first argument."
    exit 1
fi

echo -e "${BLUE}==> Installing ${PROJECT_SLUG} into local project folders...${NC}"
echo -e "Repository: ${REPO_URL}"
echo -e "Reference : ${REPO_REF}"

mkdir -p "${VAPI_DIR}" "${LIB_DIR}" "${INCLUDE_DIR}"

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

SOURCE_DIR=""

try_download_release_zip() {
  local out_zip="$1"
  local tag_zip_url="https://github.com/${GITHUB_REPO}/releases/download/${REPO_REF}/${PROJECT_SLUG}-${REPO_REF}-linux.zip"
  if curl -fsSL "${tag_zip_url}" -o "${out_zip}"; then
    return 0
  fi

  local latest_api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
  local latest_zip_url
  latest_zip_url="$(curl -fsSL "${latest_api_url}" | grep -o "https://[^\"]*${PROJECT_SLUG}-[^\"]*-linux\\.zip" | head -n 1 || true)"
  if [ -n "${latest_zip_url}" ] && curl -fsSL "${latest_zip_url}" -o "${out_zip}"; then
    return 0
  fi

  return 1
}

RELEASE_ZIP="${TMP_DIR}/release.zip"
if try_download_release_zip "${RELEASE_ZIP}"; then
  if ! command -v unzip >/dev/null 2>&1; then
    echo -e "${RED}[Error] unzip is required to extract release bundle.${NC}"
    exit 1
  fi

  echo -e "${BLUE}==> Using prebuilt release ZIP...${NC}"
  mkdir -p "${TMP_DIR}/bundle"
  unzip -q "${RELEASE_ZIP}" -d "${TMP_DIR}/bundle"
  SOURCE_DIR="${TMP_DIR}/bundle"
else
  echo -e "${BLUE}==> Release ZIP not found, building from source...${NC}"
  echo -e "${BLUE}==> Cloning source...${NC}"
  git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${TMP_DIR}/src" >/dev/null 2>&1

  echo -e "${BLUE}==> Building release artifacts...${NC}"
  meson setup "${TMP_DIR}/build" "${TMP_DIR}/src" --buildtype=release >/dev/null
  meson compile -C "${TMP_DIR}/build" >/dev/null
  SOURCE_DIR="${TMP_DIR}/build/src"
fi

SOURCE_VAPI="${SOURCE_DIR}/vapi/${PROJECT_SLUG}.vapi"
SOURCE_HEADER="${SOURCE_DIR}/${PROJECT_SLUG}.h"

if [ ! -f "${SOURCE_VAPI}" ] || [ ! -f "${SOURCE_HEADER}" ] || ! compgen -G "${SOURCE_DIR}/lib${PROJECT_SLUG}.so*" > /dev/null; then
  echo -e "${RED}[Error] Expected artifacts were not found.${NC}"
  exit 1
fi

echo -e "${BLUE}==> Copying artifacts...${NC}"
cp "${SOURCE_VAPI}" "${VAPI_DIR}/"
cp "${SOURCE_HEADER}" "${INCLUDE_DIR}/"
cp -a "${SOURCE_DIR}"/lib${PROJECT_SLUG}.so* "${LIB_DIR}/"

if ! grep -Fq "${START_MARKER}" "${MESON_FILE}"; then
    echo -e "${BLUE}==> Appending helper block to meson.build...${NC}"
    cat <<EOF >> "${MESON_FILE}"

${START_MARKER}
${PROJECT_SLUG//-/_}_local_deps = [
  dependency('glib-2.0'),
  dependency('gio-2.0'),
]

${PROJECT_SLUG//-/_}_local_vala_args = [
  '--vapidir=' + meson.project_source_root() / 'vapi',
]

${PROJECT_SLUG//-/_}_local_c_args = [
  '-I' + meson.project_source_root() / 'include',
]

${PROJECT_SLUG//-/_}_local_link_args = [
  '-L' + meson.project_source_root() / 'lib',
  '-l${PROJECT_SLUG}',
]
${END_MARKER}
EOF
else
    echo -e "${BLUE}==> meson.build helper block already exists, skipping append.${NC}"
fi

echo -e "${GREEN}[Done] Local integration files prepared.${NC}"
echo -e ""
echo -e "Use these variables in your target definition:"
echo -e "  dependencies: ${PROJECT_SLUG//-/_}_local_deps"
echo -e "  vala_args: ${PROJECT_SLUG//-/_}_local_vala_args"
echo -e "  c_args: ${PROJECT_SLUG//-/_}_local_c_args"
echo -e "  link_args: ${PROJECT_SLUG//-/_}_local_link_args"
echo -e ""
echo -e "Run your app with local shared library path if needed:"
echo -e "  LD_LIBRARY_PATH=./lib ./your-binary"

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ "${KEEP_SCRIPT:-0}" != "1" ] && [ -n "${SCRIPT_PATH}" ] && [ -f "${SCRIPT_PATH}" ]; then
  rm -f -- "${SCRIPT_PATH}" || true
fi
