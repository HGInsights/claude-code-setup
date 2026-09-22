#!/bin/zsh

# Git Worktree Setup Function
# Usage: wt <feature-name>
# Creates a worktree in adjacent -worktrees folder and opens in Cursor
wt() {
    # Check if feature name argument is provided
    if [ -z "$1" ]; then
        echo "Usage: wt <feature-name>"
        echo "Example: wt user-authentication"
        return 1
    fi

    # Store the feature name from the first argument
    local FEATURE_NAME="$1"

    # Get the current directory (project folder) name
    local CURRENT_DIR=$(basename "$(pwd)")

    # Get the parent directory path
    local PARENT_DIR=$(dirname "$(pwd)")

    # Create the worktrees folder name by appending -worktrees to current project name
    local WORKTREES_DIR="$PARENT_DIR/${CURRENT_DIR}-worktrees"

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi

    # Create the worktrees directory if it doesn't exist
    if [ ! -d "$WORKTREES_DIR" ]; then
        echo "Creating worktrees directory: $WORKTREES_DIR"
        mkdir -p "$WORKTREES_DIR"
    fi

    # Define the path for the new worktree
    local WORKTREE_PATH="$WORKTREES_DIR/$FEATURE_NAME"

    # Check if worktree already exists
    if [ -d "$WORKTREE_PATH" ]; then
        echo "Error: Worktree '$FEATURE_NAME' already exists at $WORKTREE_PATH"
        return 1
    fi

    # Resolve the repo's default branch (master/main) and fetch it fresh, so the
    # new worktree is based on the current remote tip rather than a stale local HEAD.
    local DEFAULT_BRANCH
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    [ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="master"
    echo "🔄 Fetching origin/$DEFAULT_BRANCH..."
    git fetch origin "$DEFAULT_BRANCH" --quiet || echo "   ⚠️  fetch failed; basing worktree on local origin/$DEFAULT_BRANCH"

    # Create the git worktree with new branch, based on the fresh remote tip
    echo "Creating git worktree and branch '$FEATURE_NAME' from origin/$DEFAULT_BRANCH..."
    if git worktree add -b "$FEATURE_NAME" "$WORKTREE_PATH" "origin/$DEFAULT_BRANCH"; then
        echo "✅ Successfully created worktree: $WORKTREE_PATH"
        
        # Copy .env files, pruning node_modules/.git/.next so we don't drag dependency fixtures
        echo "🔧 Copying .env files..."
        local env_files_found=false
        while IFS= read -r -d '' env_file; do
            local rel_path="${env_file#$(pwd)/}"
            local target_dir="$WORKTREE_PATH/$(dirname "$rel_path")"
            mkdir -p "$target_dir"
            cp "$env_file" "$target_dir/"
            echo "   📄 Copied: $rel_path"
            env_files_found=true
        done < <(command find "$(pwd)" \( -name node_modules -o -name .git -o -name .next \) -prune -o -type f -name ".env*" -print0)

        if [ "$env_files_found" = false ]; then
            echo "   ℹ️  No .env files found to copy"
        fi

        # Copy top-level .claude folder only (local agent config, gitignored)
        if [ -d "$(pwd)/.claude" ]; then
            echo "🔧 Copying .claude folder..."
            cp -R "$(pwd)/.claude" "$WORKTREE_PATH/"
            echo "   📁 Copied: .claude"
        fi
        
        # Open the new worktree in Cursor editor in a new window
        echo "🚀 Opening '$FEATURE_NAME' worktree in Cursor..."
        if command -v cursor > /dev/null 2>&1; then
            cursor -n "$WORKTREE_PATH"
        else
            echo "⚠️  Cursor CLI not found. Install it via Cursor > Command Palette > 'Shell Command: Install cursor command in PATH'"
            echo "📁 Worktree created at: $WORKTREE_PATH"
        fi
        
        echo "🎉 Done! Your feature branch '$FEATURE_NAME' is ready for development."
    else
        echo "❌ Failed to create git worktree"
        return 1
    fi
}
