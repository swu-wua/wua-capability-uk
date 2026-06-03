#!/usr/bin/env bash
# One-shot deploy for the UK variant.
# Same flow as the KSA repo: copy → git init → GitHub repo → Vercel deploy.
# Re-run safely — it skips steps that are already done.

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
REPO_NAME="wua-capability-uk"
REPO_VISIBILITY="public"            # "public" or "private"
DEST_DIR="$HOME/Documents/$REPO_NAME"

SRC_DIR="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/879fe105-5eae-41f9-aa48-70571c0bee56/b8833c33-87cd-4a94-8044-20a313b79f26/local_af6330e8-f853-4707-99cb-8a2ce0930ab3/outputs/wua-site-uk"
# ─────────────────────────────────────────────────────────────────────────────

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m✓\033[0m %s\n" "$*"; }
warn()  { printf "\033[33m!\033[0m %s\n" "$*"; }
die()   { printf "\033[31m✗\033[0m %s\n" "$*" >&2; exit 1; }

bold "▸ Prerequisites"
for tool in git gh vercel; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    warn "$tool missing — installing"
    [ "$tool" = "vercel" ] && brew install vercel-cli || brew install "$tool"
  fi
  green "$tool"
done

[ -d "$SRC_DIR" ] || die "Source not found: $SRC_DIR"

bold "▸ Working folder $DEST_DIR"
if [ -d "$DEST_DIR/.git" ]; then
  green "Already initialized — using existing"
else
  mkdir -p "$DEST_DIR"
  rsync -a --delete --exclude='.git' "$SRC_DIR/" "$DEST_DIR/"
  green "Copied source files"
fi
cd "$DEST_DIR"

bold "▸ GitHub auth"
if ! gh auth status >/dev/null 2>&1; then
  warn "Logging in"
  gh auth login
fi
GH_USER=$(gh api user --jq .login)
green "Logged in as $GH_USER"

bold "▸ Git repo"
if [ ! -d .git ]; then
  git init -b main >/dev/null
  green "git init"
fi
git add .
if git diff --cached --quiet; then
  green "Nothing new to commit"
else
  git -c user.email="${USER}@local" -c user.name="$USER" commit -m "Update UK capability statement" >/dev/null
  green "Commit created"
fi

bold "▸ GitHub repo"
if gh repo view "$GH_USER/$REPO_NAME" >/dev/null 2>&1; then
  green "Repo $GH_USER/$REPO_NAME already exists"
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git"
  git push -u origin main
else
  gh repo create "$REPO_NAME" --"$REPO_VISIBILITY" --source=. --remote=origin --push
  green "Repo created and pushed"
fi
REPO_URL="https://github.com/$GH_USER/$REPO_NAME"
green "GitHub: $REPO_URL"

bold "▸ Vercel"
if ! vercel whoami >/dev/null 2>&1; then
  warn "Logging in"
  vercel login
fi
if [ ! -f .vercel/project.json ]; then
  vercel link --yes --project "$REPO_NAME" >/dev/null || vercel link --yes >/dev/null
  green "Vercel project linked"
fi
DEPLOY_URL=$(vercel --prod --yes 2>&1 | tee /tmp/vercel-uk.log | grep -Eo "https://[a-zA-Z0-9.-]+\.vercel\.app" | tail -1)

echo
bold "✅ Done"
echo "  GitHub : $REPO_URL"
echo "  Site   : ${DEPLOY_URL:-check Vercel dashboard}"
echo
echo "Next: in Vercel dashboard → wua-capability-uk → Settings → Domains, add"
echo "      bd-uk.wuastudio.com  (then add the CNAME at your DNS registrar)"
