#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo -e "${BOLD}${BLUE}  GitHub Multi-Account — $1${NC}"
    echo -e "${BOLD}${BLUE}========================================${NC}"
    echo ""
}

print_step()    { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error()   { echo -e "${RED}✗ $1${NC}"; }

print_action() {
    echo ""
    echo -e "${YELLOW}${BOLD}ACTION REQUIRED:${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo ""
    read -rp "Press Enter when done..."
    echo ""
}

expand_path() {
    echo "${1/#\~/$HOME}"
}

# ─── Welcome ────────────────────────────────────────────────────────────────

print_header "Setup for Mac"
echo "This script will guide you through:"
echo "  1. Collecting your GitHub account details"
echo "  2. Generating a separate SSH key for each account"
echo "  3. Configuring ~/.ssh/config with host aliases"
echo "  4. Creating per-directory git profiles"
echo "  5. Adding your public keys to GitHub"
echo "  6. Verifying both connections"
echo ""
echo -e "${YELLOW}Existing configs will be backed up before any changes are made.${NC}"
echo ""
read -rp "Press Enter to begin..."

print_header "Step 1 — Personal GitHub Account"

while [[ -z "$PERSONAL_USERNAME" ]]; do
    read -rp "GitHub username: " PERSONAL_USERNAME
done
PERSONAL_EMAIL="${PERSONAL_USERNAME}@users.noreply.github.com"
print_success "Email set to $PERSONAL_EMAIL"
read -rp "Workspace directory [~/Workspace/personal]: " PERSONAL_DIR_RAW
PERSONAL_DIR=$(expand_path "${PERSONAL_DIR_RAW:-~/Workspace/personal}")

print_header "Step 2 — Work GitHub Account"

while [[ -z "$WORK_USERNAME" ]]; do
    read -rp "GitHub username: " WORK_USERNAME
done
WORK_EMAIL="${WORK_USERNAME}@users.noreply.github.com"
print_success "Email set to $WORK_EMAIL"
read -rp "Workspace directory [~/Workspace/work]: " WORK_DIR_RAW
WORK_DIR=$(expand_path "${WORK_DIR_RAW:-~/Workspace/work}")

print_header "Step 3 — Default Account"

echo "Which account should be used for repos cloned outside both workspaces?"
echo "  1) Personal ($PERSONAL_USERNAME)"
echo "  2) Work     ($WORK_USERNAME)"
echo ""
DEFAULT_CHOICE=""
while [[ "$DEFAULT_CHOICE" != "1" && "$DEFAULT_CHOICE" != "2" ]]; do
    read -rp "Choice [1/2]: " DEFAULT_CHOICE
done

if [[ "$DEFAULT_CHOICE" == "1" ]]; then
    DEFAULT_USERNAME="$PERSONAL_USERNAME"
    DEFAULT_KEY="$HOME/.ssh/id_ed25519_personal"
    DEFAULT_HOST="github.com-personal"
else
    DEFAULT_USERNAME="$WORK_USERNAME"
    DEFAULT_KEY="$HOME/.ssh/id_ed25519_work"
    DEFAULT_HOST="github.com-work"
fi

print_header "Step 4 — Generating SSH Keys"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

PERSONAL_KEY="$HOME/.ssh/id_ed25519_personal"
WORK_KEY="$HOME/.ssh/id_ed25519_work"

if [ -f "$PERSONAL_KEY" ]; then
    print_warning "Personal SSH key already exists at $PERSONAL_KEY — skipping"
else
    print_step "Generating personal SSH key..."
    ssh-keygen -t ed25519 -C "$PERSONAL_EMAIL" -f "$PERSONAL_KEY" -N ""
    print_success "Saved to $PERSONAL_KEY"
fi

if [ -f "$WORK_KEY" ]; then
    print_warning "Work SSH key already exists at $WORK_KEY — skipping"
else
    print_step "Generating work SSH key..."
    ssh-keygen -t ed25519 -C "$WORK_EMAIL" -f "$WORK_KEY" -N ""
    print_success "Saved to $WORK_KEY"
fi

print_header "Step 5 — Configuring ~/.ssh/config"

SSH_CONFIG="$HOME/.ssh/config"
PERSONAL_HOST="github.com-personal"
WORK_HOST="github.com-work"

PERSONAL_SSH_EXISTS=false
WORK_SSH_EXISTS=false
DEFAULT_SSH_EXISTS=false

if [ -f "$SSH_CONFIG" ]; then
    grep -q "Host $PERSONAL_HOST" "$SSH_CONFIG" 2>/dev/null && PERSONAL_SSH_EXISTS=true
    grep -q "Host $WORK_HOST"     "$SSH_CONFIG" 2>/dev/null && WORK_SSH_EXISTS=true
    grep -qE "^Host github\.com$" "$SSH_CONFIG" 2>/dev/null && DEFAULT_SSH_EXISTS=true
fi

if $PERSONAL_SSH_EXISTS && $WORK_SSH_EXISTS; then
    print_warning "SSH config entries already exist — skipping"
else
    if [ -f "$SSH_CONFIG" ]; then
        cp "$SSH_CONFIG" "${SSH_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
        print_success "Backed up existing SSH config"
    fi
    touch "$SSH_CONFIG"

    if ! $PERSONAL_SSH_EXISTS; then
        cat >> "$SSH_CONFIG" << EOF

# Personal GitHub account ($PERSONAL_USERNAME)
Host $PERSONAL_HOST
    HostName github.com
    User git
    IdentityFile $PERSONAL_KEY
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
EOF
        print_success "Added $PERSONAL_HOST to SSH config"
    fi

    if ! $WORK_SSH_EXISTS; then
        cat >> "$SSH_CONFIG" << EOF

# Work GitHub account ($WORK_USERNAME)
Host $WORK_HOST
    HostName github.com
    User git
    IdentityFile $WORK_KEY
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
EOF
        print_success "Added $WORK_HOST to SSH config"
    fi

    if ! $DEFAULT_SSH_EXISTS; then
        cat >> "$SSH_CONFIG" << EOF

# Default GitHub — falls back to $DEFAULT_USERNAME
Host github.com
    HostName github.com
    User git
    IdentityFile $DEFAULT_KEY
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
EOF
        print_success "Set $DEFAULT_USERNAME as default github.com identity"
    fi
fi

chmod 600 "$SSH_CONFIG"

print_step "Adding keys to SSH agent and macOS keychain..."

ssh-add --apple-use-keychain "$PERSONAL_KEY" 2>/dev/null \
    || ssh-add -K "$PERSONAL_KEY" 2>/dev/null \
    || ssh-add "$PERSONAL_KEY" 2>/dev/null \
    || print_warning "Could not add personal key automatically — run: ssh-add $PERSONAL_KEY"

ssh-add --apple-use-keychain "$WORK_KEY" 2>/dev/null \
    || ssh-add -K "$WORK_KEY" 2>/dev/null \
    || ssh-add "$WORK_KEY" 2>/dev/null \
    || print_warning "Could not add work key automatically — run: ssh-add $WORK_KEY"

print_success "Keys loaded into SSH agent"

print_header "Step 6 — Creating Git Profiles"

PERSONAL_GITCONFIG="$HOME/.gitconfig-personal"
WORK_GITCONFIG="$HOME/.gitconfig-work"

if [ -f "$PERSONAL_GITCONFIG" ]; then
    cp "$PERSONAL_GITCONFIG" "${PERSONAL_GITCONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    print_success "Backed up $PERSONAL_GITCONFIG"
fi

cat > "$PERSONAL_GITCONFIG" << EOF
[user]
	name = $PERSONAL_USERNAME
	email = $PERSONAL_EMAIL

[url "git@$PERSONAL_HOST:"]
	insteadOf = git@github.com:
	insteadOf = https://github.com/
EOF
print_success "Created $PERSONAL_GITCONFIG"

if [ -f "$WORK_GITCONFIG" ]; then
    cp "$WORK_GITCONFIG" "${WORK_GITCONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    print_success "Backed up $WORK_GITCONFIG"
fi

cat > "$WORK_GITCONFIG" << EOF
[user]
	name = $WORK_USERNAME
	email = $WORK_EMAIL

[url "git@$WORK_HOST:"]
	insteadOf = git@github.com:
	insteadOf = https://github.com/
EOF
print_success "Created $WORK_GITCONFIG"

print_header "Step 7 — Updating Global Git Config"

GLOBAL_GITCONFIG="$HOME/.gitconfig"

if [ -f "$GLOBAL_GITCONFIG" ]; then
    cp "$GLOBAL_GITCONFIG" "${GLOBAL_GITCONFIG}.bak.$(date +%Y%m%d%H%M%S)"
    print_success "Backed up ~/.gitconfig"
fi

touch "$GLOBAL_GITCONFIG"

if grep -qF "gitdir:$PERSONAL_DIR/" "$GLOBAL_GITCONFIG" 2>/dev/null; then
    print_warning "Personal includeIf already in ~/.gitconfig — skipping"
else
    cat >> "$GLOBAL_GITCONFIG" << EOF

[includeIf "gitdir:$PERSONAL_DIR/"]
	path = $PERSONAL_GITCONFIG
EOF
    print_success "Added personal profile include for $PERSONAL_DIR"
fi

if grep -qF "gitdir:$WORK_DIR/" "$GLOBAL_GITCONFIG" 2>/dev/null; then
    print_warning "Work includeIf already in ~/.gitconfig — skipping"
else
    cat >> "$GLOBAL_GITCONFIG" << EOF
[includeIf "gitdir:$WORK_DIR/"]
	path = $WORK_GITCONFIG
EOF
    print_success "Added work profile include for $WORK_DIR"
fi

print_header "Step 8 — Workspace Directories"

if [ -d "$PERSONAL_DIR" ]; then
    print_success "Personal workspace already exists: $PERSONAL_DIR"
else
    mkdir -p "$PERSONAL_DIR"
    print_success "Created $PERSONAL_DIR"
fi

if [ -d "$WORK_DIR" ]; then
    print_success "Work workspace already exists: $WORK_DIR"
else
    mkdir -p "$WORK_DIR"
    print_success "Created $WORK_DIR"
fi

print_header "Step 9 — Add SSH Keys to GitHub"

echo -e "${BOLD}Personal key — add to the $PERSONAL_USERNAME account:${NC}"
echo ""
cat "$PERSONAL_KEY.pub"
echo ""
print_action "1. Copy the key printed above
2. Open https://github.com/settings/keys  (log in as $PERSONAL_USERNAME)
3. Click 'New SSH key'
4. Title: Mac $(hostname -s) Personal
5. Paste the key → Add SSH key"

echo ""
echo -e "${BOLD}Work key — add to the $WORK_USERNAME account:${NC}"
echo ""
cat "$WORK_KEY.pub"
echo ""
print_action "1. Copy the key printed above
2. Open https://github.com/settings/keys  (log in as $WORK_USERNAME)
3. Click 'New SSH key'
4. Title: Mac $(hostname -s) Work
5. Paste the key → Add SSH key"

# ─── Step 10: Test connections ──────────────────────────────────────────────

print_header "Step 10 — Verifying Connections"

set +e

print_step "Testing personal connection (git@$PERSONAL_HOST)..."
PERSONAL_RESULT=$(ssh -T "git@$PERSONAL_HOST" -o StrictHostKeyChecking=no -o BatchMode=yes 2>&1 || true)
if echo "$PERSONAL_RESULT" | grep -q "Hi "; then
    print_success "Personal: $PERSONAL_RESULT"
else
    print_error "Personal connection failed"
    echo "  $PERSONAL_RESULT"
    echo "  Make sure you added the personal public key to the $PERSONAL_USERNAME GitHub account."
fi

print_step "Testing work connection (git@$WORK_HOST)..."
WORK_RESULT=$(ssh -T "git@$WORK_HOST" -o StrictHostKeyChecking=no -o BatchMode=yes 2>&1 || true)
if echo "$WORK_RESULT" | grep -q "Hi "; then
    print_success "Work: $WORK_RESULT"
else
    print_error "Work connection failed"
    echo "  $WORK_RESULT"
    echo "  Make sure you added the work public key to the $WORK_USERNAME GitHub account."
fi

set -e

print_header "Done"

echo "Your GitHub multi-account setup is complete."
echo ""
echo -e "  ${BOLD}Personal${NC} → ${CYAN}$PERSONAL_DIR${NC}"
echo -e "             $PERSONAL_USERNAME <$PERSONAL_EMAIL>"
echo ""
echo -e "  ${BOLD}Work${NC}     → ${CYAN}$WORK_DIR${NC}"
echo -e "             $WORK_USERNAME <$WORK_EMAIL>"
echo ""
echo -e "  ${BOLD}Default${NC}  → $DEFAULT_USERNAME (repos outside both workspaces)"
echo ""
echo "Git automatically picks the correct identity based on where the repo lives."
echo ""
echo -e "${CYAN}To verify, cd into a repo in each workspace and run:${NC}"
echo "  git config user.email"
echo ""
echo -e "${YELLOW}When cloning, use the host alias instead of github.com:${NC}"
echo "  Personal:  git clone git@github.com-personal:username/repo.git"
echo "  Work:      git clone git@github.com-work:username/repo.git"
echo ""
