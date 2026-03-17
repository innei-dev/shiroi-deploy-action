# Standalone PM2 Template Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store and deploy a standalone-specific PM2 config from the Action repository.

**Architecture:** Add a tracked PM2 template file under this repository and treat it as deploy input alongside `release.zip`. The deploy script will install that file into `$basedir/ecosystem.config.js` and then use `pm2 start/reload` against the same config.

**Tech Stack:** GitHub Actions, bash, PM2, Next.js standalone output

---

### Task 1: Add Standalone PM2 Template

**Files:**
- Create: `pm2/ecosystem.config.js`

- [ ] **Step 1: Add tracked PM2 template**

Create a CommonJS PM2 config that starts `./server.js` from the deployment base directory.

- [ ] **Step 2: Encode standalone runtime defaults**

Include `NODE_ENV=production`, `HOSTNAME=0.0.0.0`, and a default `PORT`.

### Task 2: Wire Template Into Deploy Workflow

**Files:**
- Modify: `.github/workflows/deploy.yml`

- [ ] **Step 1: Copy template into workflow workspace**

Prepare `ecosystem.config.js` before SCP upload.

- [ ] **Step 2: Upload template to target host**

Send the generated `ecosystem.config.js` alongside `release.zip`.

- [ ] **Step 3: Install template into basedir**

Write the uploaded config into `$basedir/ecosystem.config.js`.

- [ ] **Step 4: Use start-or-reload behavior**

Reload the PM2 app if it exists, otherwise start it from the same config.

### Task 3: Verify PM2 Startup

**Files:**
- Verify against: local standalone deployment simulation

- [ ] **Step 1: Check workflow syntax**

Run:

```bash
ruby -e "require 'yaml'; YAML.load_file('.github/workflows/deploy.yml')"
```

Expected: no syntax error

- [ ] **Step 2: Start PM2 with standalone template**

Run a local PM2 process with `server.js` pointing at the extracted standalone build.

Expected: Next.js reaches `Ready` and listens on the configured port
