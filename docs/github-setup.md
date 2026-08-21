# Put Mekasa on GitHub (own repo)

Mekasa currently lives as `mekasa/` inside `fernandogator/fallout`. Use these steps to give it a dedicated repository.

## 1. Create the empty GitHub repo

On your machine (or GitHub.com while signed in as **fernandogator**):

**Option A — website**

1. Open https://github.com/new
2. Owner: `fernandogator`
3. Repository name: `mekasa`
4. Private (recommended)
5. **Do not** add README, .gitignore, or license (this folder already has them)
6. Create repository

**Option B — GitHub CLI (your account)**

```bash
gh repo create fernandogator/mekasa --private --description "Mekasa — household inventory (mi casa)"
```

## 2. Push this folder as the new repo root

From a clone of fallout that contains the latest `mekasa/` folder (or from this Cloud Agent workspace after you download/copy `mekasa/`):

```bash
cd mekasa
git init -b main
git add .
git status   # confirm node_modules is NOT listed
git commit -m "Initial commit: Mekasa AI-SDLC scaffold"
git remote add origin https://github.com/fernandogator/mekasa.git
git push -u origin main
```

If GitHub shows a different default remote URL, use the one from the empty-repo page.

## 3. Open the new repo in Cursor

1. Cursor → Open folder → clone `fernandogator/mekasa`
2. Re-run Superdesign login if needed: `npx --yes @superdesign/cli@latest login`
3. Continue design with `/superdesign` in that workspace (not fallout)

## 4. Optional cleanup in fallout

After Mekasa is on its own remote and you are happy with it:

- Close or abandon the fallout PR that only added nested `mekasa/`
- Or keep a short note in fallout README pointing to `https://github.com/fernandogator/mekasa`

Do **not** copy `~/.superdesign/config.json` or any API keys into the repo.
