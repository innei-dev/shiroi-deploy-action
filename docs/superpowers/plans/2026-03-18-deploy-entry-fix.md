# Deploy Entry Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the deploy workflow so PM2 starts the real Next.js standalone entry from the built artifact.

**Architecture:** Keep the existing build and SSH deployment flow intact. Only adjust deploy-time runtime paths so the deployed server, env file, and cache path all point at `standalone/apps/web`, which is the verified runtime root in the built bundle.

**Tech Stack:** GitHub Actions, bash, PM2, Next.js standalone output

---

### Task 1: Fix Deploy Runtime Paths

**Files:**
- Modify: `.github/workflows/deploy.yml`

- [ ] **Step 1: Update `.env` link target**

Change the deploy script to place the runtime `.env` symlink at `$workdir/standalone/apps/web/.env`.

- [ ] **Step 2: Update server entry symlink**

Change the deploy script to point `$basedir/server.js` at `$workdir/standalone/apps/web/server.js`.

- [ ] **Step 3: Update cache link target**

Change the deploy script to create `.next/cache` under `$workdir/standalone/apps/web/.next/cache`.

- [ ] **Step 4: Check workflow syntax**

Run:

```bash
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/deploy.yml')"
```

Expected: no syntax error

### Task 2: Re-verify Artifact Layout

**Files:**
- Verify against: source repo checkout in `/tmp/shiroi-build-check.lxfXxs`

- [ ] **Step 1: Re-run local build evidence**

Run:

```bash
cd /tmp/shiroi-build-check.lxfXxs
sh ./ci-release-build.sh
```

Expected: build completes and writes `assets/release.zip`

- [ ] **Step 2: Verify runtime files in zip**

Run:

```bash
unzip -l /tmp/shiroi-build-check.lxfXxs/assets/release.zip | rg 'standalone/apps/web/\.next/(BUILD_ID|server|static)|standalone/apps/web/server\.js'
```

Expected: matching runtime paths are present

- [ ] **Step 3: Simulate basedir startup**

Run a local symlink-based startup where `server.js` points to the extracted `standalone/apps/web/server.js`.

Expected: Next.js reaches `Ready`
