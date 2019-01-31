# removes trailing spaces
find . -name "*.sml" -type f -print0 | xargs -0 sed -i 's/[[:space:]]*$//'

# expand tabs to spaces
find . -name '*.sml' ! -type d -exec bash -c 'expand "$0" > /tmp/e && mv /tmp/e "$0"' {} \;
