# Shiroi Deploy to Remote Server Workflow

这是一个利用 GitHub Action 去构建当前私有版本站点并部署到远程服务器的工作流。

## Why?

这里的项目关系现在更准确地说是：

- [Yohaku](https://github.com/Innei/Yohaku) 是当前设计语言与视觉体系已经完全重构后的闭源完整实现。
- [Shiro](https://github.com/Innei/Shiro) 是更早期的开源来源项目。
- `Shiroi` 更接近 Yohaku 在大改版之前的历史阶段或兼容称呼；如果你需要旧设计风格，可以切换到 `Shiroi` 对应的历史版本。

开源版本通常提供了预构建的 Docker 镜像或者编译产物可直接使用，但是当前私有完整实现并没有提供。

因为 Next.js build 需要大量内存，很多服务器并吃不消这样的开销。

因此这里提供利用 GitHub Action 去完成构建然后推送到服务器。

你可以使用定时任务去定时更新 Yohaku，或部署旧风格的 Shiroi 历史版本。

## How to

开始之前，你的服务器首先需要安装 Node.js, npm, pnpm, pm2, sharp。

关于 sharp 的安装，你可以使用

```sh
npm i -g sharp
```

sharp 不是必须的，但是在运行过程中会出现报错。参考：https://nextjs.org/docs/messages/sharp-missing-in-production

在你的服务器家目录，新建 `shiro` 的目录，然后新建 `.env` 填写你的变量。

```
# Env from your private Yohaku/Shiroi repo .env.template
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

## Secrets

- `HOST` 服务器地址
- `USER` 服务器用户名
- `PASSWORD` 服务器密码
- `PORT` 服务器 SSH 端口
- `KEY` 服务器 SSH Key（可选，密码 key 二选一）
- `GH_PAT` 可访问当前私有源码仓库的 Github Token

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
