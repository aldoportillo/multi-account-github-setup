# github-multi-account-setup

A guided bash script that walks you through setting up two GitHub accounts (personal + work) on the same Mac — with automatic profile switching based on which directory your repo lives in.

No more committing as the wrong user, no juggling credentials manually.

---

## What it does

1. Prompts for your personal and work GitHub usernames, emails, and workspace directories
2. Generates a separate ed25519 SSH key for each account
3. Adds both keys to `~/.ssh/config` with unique host aliases and macOS Keychain integration
4. Creates `~/.gitconfig-personal` and `~/.gitconfig-work` with per-account identity and URL rewriting
5. Adds `includeIf` directives to your global `~/.gitconfig` so git picks the right profile by directory
6. Pauses and guides you through adding each public key to the correct GitHub account
7. Tests both SSH connections and reports results

Existing files are backed up with a timestamp before anything is modified. The script is safe to re-run.

---

## Requirements

- macOS
- `git` and `ssh`

---

## Usage

```bash
git clone https://github.com/aldoportillo/github-multi-account-setup.git
cd github-multi-account-setup
./setup.sh
```

---

## How it works

**Directory-based identity switching**

Git's `includeIf "gitdir:..."` directive conditionally loads a config file based on where the repo lives. The script adds two of these to your global `~/.gitconfig`:

```gitconfig
[includeIf "gitdir:~/Workspace/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir:~/Workspace/work/"]
    path = ~/.gitconfig-work
```

Each profile sets the correct `user.name` / `user.email` and rewrites GitHub URLs to use the account-specific SSH host alias.

**SSH host aliases**

`~/.ssh/config` maps two aliases to `github.com` with different identity files:

```
Host github.com-personal
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_personal

Host github.com-work
    HostName github.com
    IdentityFile ~/.ssh/id_ed25519_work
```

**URL rewriting**

Each gitconfig profile rewrites `git@github.com:` and `https://github.com/` to the correct alias automatically, so standard clone URLs just work once the repo is in the right workspace.

---

## Cloning repos

After setup, clone into the correct workspace directory:

```bash
# Personal repos
cd ~/Workspace/personal
git clone git@github.com-personal:username/repo.git

# Work repos
cd ~/Workspace/work
git clone git@github.com-work:org/repo.git
```

Once cloned, `git pull`, `git push`, etc. all work normally — no alias needed after the initial clone.

---

## Verifying the setup

```bash
# In a personal repo
cd ~/Workspace/personal/some-repo
git config user.email   # → your personal email

# In a work repo
cd ~/Workspace/work/some-repo
git config user.email   # → your work email
```

---

## What gets created

| File | Purpose |
|---|---|
| `~/.ssh/id_ed25519_personal` | SSH key for personal account |
| `~/.ssh/id_ed25519_work` | SSH key for work account |
| `~/.ssh/config` | Host aliases mapping each key to `github.com` |
| `~/.gitconfig-personal` | Personal identity + URL rewrite rules |
| `~/.gitconfig-work` | Work identity + URL rewrite rules |
| `~/.gitconfig` | Global config updated with `includeIf` directives |

---

## Security

- Private keys stay on your machine in `~/.ssh/` and are never printed or stored anywhere else.
- Keys are added to the macOS Keychain so you only unlock them once per login session.
- If a key is compromised, revoke it on GitHub (Settings → SSH keys) and re-run the script to generate a new one.
