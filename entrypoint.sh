#!/usr/bin/env bash

if [[ ! $INPUT_LANGUAGES ]]; then
    echo 'No languages selected!'
    exit 1;
fi

# Get languages as array
IFS=', ' read -r -a LANGUAGES <<< "$INPUT_LANGUAGES"

# Ensure we have a directory to work in
if [[ $DRY_RUN ]]; then
    echo 'mkdir -p tmp'
else
    rm -rf tmp
fi

mkdir -p tmp

# Allow github to pass env vars with a hyphen instead of underscore
GITHUB_INPUT_SSH_KEY_PRIVATE=`env | sed -n 's/INPUT_SSH-KEY-PRIVATE=\(.*\)/\1/p'`
GITHUB_INPUT_SSH_KEY_PUBLIC=`env | sed -n 's/INPUT_SSH-KEY-PUBLIC=\(.*\)/\1/p'`
INPUT_SSH_KEY_PRIVATE=${GITHUB_INPUT_SSH_KEY_PRIVATE:-$INPUT_SSH_KEY_PRIVATE}
INPUT_SSH_KEY_PUBLIC=${GITHUB_INPUT_SSH_KEY_PUBLIC:-$INPUT_SSH_KEY_PUBLIC}

# Setup SSH keys if we're passed them
if [[ $INPUT_SSH_KEY_PUBLIC ]]; then
    mkdir ~/.ssh/
    # Add keys
    echo "$INPUT_SSH_KEY_PRIVATE" > ~/.ssh/id_rsa
    echo "$INPUT_SSH_KEY_PUBLIC" > ~/.ssh/id_rsa.pub
    # Verifiy keys
    ssh-keygen -l -f ~/.ssh/id_rsa.pub
    # Add github.com to known hosts
    ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
    # Set correct permissions
    chmod 600 ~/.ssh/id_rsa
fi

cat ~/.ssh/id_rsa.pub

# SSH directory should exist now otherwise bail
if [[ ! $DRY_RUN ]] && [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
    echo "Missing SSH file needed for committing"
    exit 1;
fi

# Get translation-manager
if [[ $DRY_RUN ]]; then
    [ -f "./tmp/translation-manager/bin/sync" ] || echo "git clone https://github.com/unraid/translation-manager ./tmp/translation-manager"
else
    [ -f "./tmp/translation-manager/bin/sync" ] || git clone https://github.com/unraid/translation-manager ./tmp/translation-manager
fi

# Reassign for easier use
sync=./tmp/translation-manager/bin/sync

# Checkout each language that's enabled
for LANGUAGE in "${LANGUAGES[@]}"; do
    if [[ $DRY_RUN ]]; then
        echo "git clone https://github.com/limetech/lang-$LANGUAGE ./tmp/lang-$LANGUAGE"
    fi

    git clone "https://github.com/limetech/lang-$LANGUAGE" "./tmp/lang-$LANGUAGE"
done

# Sync each file
for file in *.txt **/*.txt; do
    [ -f "$file" ] || continue
    for LANGUAGE in "${LANGUAGES[@]}"; do
        filePath="./tmp/lang-$LANGUAGE/$file"
        if [[ $DRY_RUN ]]; then
            # Show missing files
            [ -f "./tmp/lang-$LANGUAGE/$file" ] || echo "mkdir -p ${filePath%/*} && touch ./tmp/lang-$LANGUAGE/$file"

            # Show what sync will run
            echo "sync ./$file" "./tmp/lang-$LANGUAGE/$file" "./tmp/lang-$LANGUAGE/$file"
        else
            # Create missing translation files            
            [ -f "./tmp/lang-$LANGUAGE/$file" ] || mkdir -p "${filePath%/*}" && touch "./tmp/lang-$LANGUAGE/$file"

            # Run sync
            $sync "./$file" "./tmp/lang-$LANGUAGE/$file" "./tmp/lang-$LANGUAGE/$file"
        fi
    done
done

# Commit and push changes to new branch
for LANGUAGE in "${LANGUAGES[@]}"; do
    # Save for cleanup
    LAST_DIR=$PWD
    
    # Enter directory
    cd "$PWD/tmp/lang-$LANGUAGE"
    if [[ $DRY_RUN ]]; then
        echo "cd $PWD/tmp/lang-$LANGUAGE"
    fi

    # Ensure we use the ssh key for connecting and tell git who we are
    if [[ $DRY_RUN ]]; then
        echo 'git config url."git@github.com:".insteadOf "https://github.com/"'
        echo 'git config user.email "bot@unraid.net"'
        echo 'git config user.name "unraid-bot"'
    else
        git config url."git@github.com:".insteadOf "https://github.com/"
        git config user.email "bot@unraid.net"
        git config user.name "unraid-bot"
    fi
    
    # Add all changes
    git add -A
    if [[ $DRY_RUN ]]; then
        echo "git add -A"
    fi

    # Branch
    VERSION=$(date '+%Y%m%d%H%M')
    BRANCH="bot-update-$VERSION"
    if [[ $DRY_RUN ]]; then
        echo "git checkout -b $BRANCH"
    else
        git checkout -b $BRANCH
    fi

    # Commit
    if [[ $DRY_RUN ]]; then
        echo "git commit -m chore: update language files"
    else
        git commit -m "chore: update language files"
    fi

    # Push
    if [[ $DRY_RUN ]]; then
        echo "git push --set-upstream origin $BRANCH"
    else
        git push --set-upstream origin $BRANCH
    fi
    
    # Cleanup for next loop
    cd $LAST_DIR
done
