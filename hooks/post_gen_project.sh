#!/usr/bin/env bash
set -euxo pipefail 

# Move gitignore template
mv .gitignore_template .gitignore

# Intitalize a git repository
git init

# Create template dirs
mkdir -p data/{raw,external}
 
