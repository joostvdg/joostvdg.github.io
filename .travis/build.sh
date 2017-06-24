#!/usr/bin/env bash
git config --global user.email ${GIT_EMAIL}
git config --global user.name ${GIT_NAME}
git remote add github https://${GH_TOKEN}@github.com/joostvdg/joostvdg.github.io.git
mkdocs gh-deploy --clean --remote-branch master --remote-name github --force --verbose