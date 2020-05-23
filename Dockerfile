FROM debian:10.1

LABEL "com.github.actions.name"="Translation sync action"
LABEL "com.github.actions.description"="Github action for syncing our translations"
LABEL "com.github.actions.icon"="git-branch"
LABEL "com.github.actions.color"="gray-dark"
LABEL "repository"="https://github.com/unraid/translation-sync-action"
LABEL "maintainer"="Alexis Tyler"

# Install curl, git and npm
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y git npm

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]