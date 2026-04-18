# Yohaku Deploy Action

> **Note:** 本仓库已重命名为 **yohaku-deploy-action**（原名为 `shiroi-deploy-action`）。GitHub 会自动处理旧链接的重定向，原有 fork 和引用不受影响。

这是一个利用 GitHub Action 去构建私有版本站点并部署到远程服务器的工作流。

## Why?

这里的项目关系现在更准确地说是：

- [Yohaku](https://github.com/Innei/Yohaku) 是当前设计语言与视觉体系已经完全重构后的闭源完整实现。
- [Shiro](https://github.com/Innei/Shiro) 是更早期的开源来源项目。
- `Shiroi` 更接近 Yohaku 在大改版之前的历史阶段或兼容称呼；如果你需要旧设计风格，可以切换到 `Shiroi` 对应的历史版本。

开源版本通常提供了预构建的 Docker 镜像或者编译产物可直接使用，但是当前私有完整实现并没有提供。

因为 Next.js build 需要大量内存，很多服务器并吃不消这样的开销。

因此这里提供利用 GitHub Action 去完成构建然后推送到服务器。

你可以使用定时任务去定时更新 Yohaku，或部署旧风格的 Shiroi 历史版本。

## 最近变更

- **仓库重命名**：`shiroi-deploy-action` → `yohaku-deploy-action`。
- **PR #17** 将默认源码仓库从 `innei-dev/shiroi` 修改为 `innei-dev/Yohaku`，以匹配当前主力项目。如果你在部署旧版 Shiroi，请将 `SOURCE_REPO` 改回 `innei-dev/shiroi`。
- 工作流已通用化：源码仓库、构建命令、产物路径均可通过环境变量覆盖，详见下节「配置项」。

## How to

开始之前，你的服务器首先需要安装 Node.js, npm, pnpm, pm2, sharp。

关于 sharp 的安装，你可以使用

```sh
npm i -g sharp
```

sharp 不是必须的，但是在运行过程中会出现报错。参考：https://nextjs.org/docs/messages/sharp-missing-in-production

在你的服务器家目录，新建 `yohaku` 的目录，然后新建 `.env` 填写你的变量。

```
# Env from your private Yohaku/Shiroi repo .env.template
BASE_URL=

NEXT_PUBLIC_API_URL=
NEXT_PUBLIC_GATEWAY_URL=

NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=

## Clerk
CLERK_SECRET_KEY=

NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/

TMDB_API_KEY=

GH_TOKEN=
```

Fork 此项目，然后你需要填写下面的信息。

## 历史版本参考

如果你需要查看或回退到**旧版 Shiroi** 的部署配置，可参考以下历史 commit：

- **[`bc07cfa`](https://github.com/innei-dev/yohaku-deploy-action/commit/bc07cfa)** —— PR #17 之前的最后一个版本，仍使用 `innei-dev/shiroi` 作为默认源码仓库，部署目录为 `~/shiro`，PM2 应用名为 `Shiroi`。

---

## 配置项

工作流支持以下环境变量（在 `.github/workflows/deploy.yml` 的 `env` 段修改，或通过 GitHub Variables 注入）：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SOURCE_REPO` | `innei-dev/Yohaku` | 私有源码仓库（格式：`owner/repo`） |
| `BUILD_COMMAND` | `pnpm --filter @yohaku/web build:ci` | 构建命令。 workflow 会在构建后自动执行 standalone 打包与 zip；如果你的项目结构不同，可修改此命令 |
| `STANDALONE_SUBPATH` | `standalone/apps/web` | 构建产物中 standalone 包的相对路径。Yohaku 与旧版 Shiroi 若结构不同，请按需调整 |

如果你部署的是旧版 **Shiroi**（monorepo 结构为 `apps/web`），通常保持默认即可；若你的仓库结构不同（例如单仓库直接输出到 `.next/standalone`），请修改 `STANDALONE_SUBPATH`。

## CI 构建与站点 URL 环境变量

工作流在 GitHub Actions 里执行 `next build` 时，会通过仓库 **Secrets** 注入 `BASE_URL`、`NEXT_PUBLIC_API_URL` 与 `NEXT_PUBLIC_GATEWAY_URL`，须与服务器 `~/yohaku/.env`（及私有仓库 `Dockerfile` / 模板）一致。

- **`BASE_URL`**：站点对外根 URL（无尾部斜杠为宜），例如 `https://example.com`。与私有镜像构建阶段一致：`Dockerfile` 中常用 `ARG BASE_URL`，并令 `NEXT_PUBLIC_GATEWAY_URL=${BASE_URL}`、`NEXT_PUBLIC_API_URL=${BASE_URL}/api/v2`。
- **`NEXT_PUBLIC_*`**：直接参与 `next build` 与客户端 bundle；若启用 **ISR**，构建期/再验证会依赖正确端点，不能只依赖部署机 `.env` 而忽略 Actions。

在仓库 **Settings → Secrets and variables → Actions** 中新增：

- `BASE_URL`
- `NEXT_PUBLIC_API_URL`
- `NEXT_PUBLIC_GATEWAY_URL`

## Secrets

- `HOST` 服务器地址
- `USER` 服务器用户名
- `PASSWORD` 服务器密码
- `PORT` 服务器 SSH 端口
- `KEY` 服务器 SSH Key（可选，密码 key 二选一）
- `GH_PAT` 可访问当前私有源码仓库的 Github Token
- `BASE_URL`、`NEXT_PUBLIC_API_URL`、`NEXT_PUBLIC_GATEWAY_URL` 供 CI 构建注入（见上一节；需与服务器 `.env` 一致）

### Github Token

1. 你的账号可以访问当前私有源码仓库（Yohaku 或你正在使用的对应私有仓库）。
2. 进入 [tokens](https://github.com/settings/tokens) - Personal access tokens - Tokens (classic) - Generate new token - Generate new token (classic)

![](https://github.com/innei-dev/yohaku-deploy-action/assets/41265413/e55d32cb-bd30-46b7-a603-7d00b3f8a413)

## Technical details

参考：[跨仓库全自动构建项目并部署到服务器](./post.md)

## Tips

为了让 PM2 在服务器重启之后能够还原进程。可以使用：

```sh
pm2 startup
pm2 save
```
