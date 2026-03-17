# Deploy Entry Fix Design

**Goal**

Fix the deploy workflow so the extracted Shiro standalone bundle is started from the actual Next.js server entry and uses the matching runtime paths.

**Problem**

`ci-release-build.sh` produces a monorepo-style standalone bundle where the runnable entry is `standalone/apps/web/server.js`, and the runtime build output lives under `standalone/apps/web/.next`.

The current deploy workflow instead points PM2 at `standalone/server.js`, and also links `.env` and `.next/cache` under `standalone/`. That path layout does not match the built artifact.

**Chosen Approach**

Keep the existing build flow unchanged and apply a minimal deploy-only fix:

- link `$basedir/server.js` to `$workdir/standalone/apps/web/server.js`
- link runtime `.env` into `$workdir/standalone/apps/web/.env`
- link cache into `$workdir/standalone/apps/web/.next/cache`

**Why This Approach**

- smallest possible change
- preserves existing PM2-based deployment model
- matches the actual artifact layout verified from local build output
- addresses issue #12 without introducing a new deployment pattern

**Verification**

- run `sh ./ci-release-build.sh` in the source repo
- inspect `assets/release.zip` for `standalone/apps/web/server.js` and `standalone/apps/web/.next/BUILD_ID`
- simulate deploy symlink layout locally and start `node server.js` from the basedir symlink target
