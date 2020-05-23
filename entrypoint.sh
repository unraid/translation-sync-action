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

# Commit changes
for LANGUAGE in "${LANGUAGES[@]}"; do
    # Save for cleanup
    LAST_DIR=$PWD
    
    # Enter directory
    cd "$PWD/tmp/lang-$LANGUAGE"
    if [[ $DRY_RUN ]]; then
        echo "cd $PWD/tmp/lang-$LANGUAGE"
    fi
    
    # Add all changes
    git add -A
    if [[ $DRY_RUN ]]; then
        echo "git add -A"
    fi

    # Branch
    VERSION=$(date '+%Y%m%d%H%M')
    if [[ $DRY_RUN ]]; then
        echo "git checkout -b bot-update-$VERSION"
    else 
        git checkout -b "bot-update-$VERSION"
    fi

    # Commit
    if [[ $DRY_RUN ]]; then
        echo "git commit -m chore: update language files"
    else 
        git commit -m "chore: update language files"
    fi

    # Push
    if [[ $DRY_RUN ]]; then
        echo "git push"
    else 
        git push
    fi
    
    # Cleanup for next loop
    cd $LAST_DIR
done