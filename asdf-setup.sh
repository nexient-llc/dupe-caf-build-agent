#!/bin/bash
set -e
git clone https://github.com/asdf-vm/asdf.git "/root/.asdf" --branch v0.11.3
source "/root/.asdf/asdf.sh"

while IFS= read -r line; do asdf plugin add "$(echo "$line" | awk '{print $1}')" || true; done < .tool-versions
asdf install

# Default to latest version in $HOME/.tool-versions
asdf global conftest 0.44.1
asdf global golang 1.20.8
asdf global golangci-lint 1.53.3
asdf global nodejs 16.13.2
asdf global opa 0.53.1
asdf global pre-commit 3.3.3
asdf global python 3.11.3
asdf global terraform 1.5.5
asdf global terraform-docs 0.16.0
asdf global terragrunt 0.51.6
asdf global tflint 0.48.0
