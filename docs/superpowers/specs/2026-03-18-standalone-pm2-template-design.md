# Standalone PM2 Template Design

**Goal**

Maintain the PM2 runtime config in the Action repository so deploy no longer depends on PM2 files that are missing or inconsistent in the source repository.

**Approach**

Add a standalone-oriented `pm2/ecosystem.config.js` template to this repository. During deploy, copy it into the workflow workspace, upload it to the target host, and write it to `$HOME/shiro/ecosystem.config.js`.

The template will always run `./server.js` from the deployment base directory. The deploy script will keep `server.js` symlinked to the current release's `standalone/apps/web/server.js`.

**Why**

- source repo PM2 files are not aligned with standalone deploy
- source repo build output does not currently include a deployable PM2 config
- Action-side ownership makes deploy behavior deterministic

**Verification**

- check workflow YAML syntax
- verify template is uploaded and written to the remote base dir in the script
- run local PM2 with the standalone template and confirm Next reaches `Ready`
