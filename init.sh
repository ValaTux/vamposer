#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_SLUG="vamposer"
DEPENDENCY_NAME="vamposer"
REPO_URL="https://github.com/ValaTux/vamposer.git"
REPO_REF="master"

echo -e "${BLUE}==> Initializing ${PROJECT_SLUG} dependency...${NC}"

if [ ! -f "meson.build" ]; then
    echo -e "${RED}[Error] 'meson.build' file not found in the current directory.${NC}"
    echo -e "Make sure you are running this script in the root folder of your Vala application."
    exit 1
fi

if [ ! -d "subprojects" ]; then
    echo -e "Creating ${BLUE}subprojects/${NC} directory..."
fi
mkdir -p "subprojects"

WRAP_FILE="subprojects/${PROJECT_SLUG}.wrap"
echo -e "Generating wrap file ${BLUE}${WRAP_FILE}${NC}..."

cat <<EOF > "$WRAP_FILE"
[wrap-git]
url = ${REPO_URL}
revision = ${REPO_REF}
depth = 1

[provide]
vamposer = ${DEPENDENCY_NAME}_deps
EOF

echo -e "${GREEN}[Done] Wrap file has been successfully created.${NC}\n"

echo -e "${BLUE}Now edit your main 'meson.build' and add the dependency:${NC}"
echo -e "--------------------------------------------------------"
echo -e "project_dep = dependency('${DEPENDENCY_NAME}', fallback: ['${PROJECT_SLUG}', 'library_dep'])"
echo -e ""
echo -e "executable("
echo -e "  'your-binary-name',"
echo -e "  'your-source-files.vala',"
echo -e "  dependencies: [ dependency('glib-2.0'), dependency('gio-2.0'), ${GREEN}project_dep${NC} ]"
echo -e ")"
echo -e "--------------------------------------------------------"
echo -e "Then build the project using:"
echo -e "${GREEN}meson setup builddir && meson compile -C builddir${NC}"
