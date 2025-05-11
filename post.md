# 跨仓库全自动构建项目并部署到服务器

最近，Vercel 又又对价格进行了调整，让 Hobby 越来越不够用了，所以放弃了使用 Vercel，转向私有服务器部署 Next.js 项目。

对于私有服务器的部署体验是非常不友好的。第一，没有 Vercel 这样的全自动部署，也不能及时回滚。第二，Next.js 项目构建需要非常大的内存和 CPU 资源，一般的轻量服务器可能在构建过程中不是爆堆就是宕机了。

## 目标

- 利用 GitHub 去构建一个通用产物，不受构建时的环境变量影响。（后者你可以通过 [一次构建多处部署 - Next.js Runtime Env
  ](https://innei.in/posts/tech/nextjs-runtime-env-and-build-once-deploy-many) 这篇文章了解更多）
- 如何推送构建产物到远程服务器
- 如何跨源代码仓库外运行构建的工作流（这个需求是因为对于闭源仓库，GitHub CI 的时长和其他都有限制；另一个，这样工作流配置仓库可以开源，而源代码仓库可以闭源）
- 如何实现回滚（可以不那么方便但是可用）

## 流程

根据上面的目标，我们可以构想出我们需要做的事，大概是这样的一个构建流程。

1. 从源码仓库检出代码，而不是工作流仓库，这点很重要。
2. 常规的代码构建
3. 区分版本，然后推送到服务器
4. 完成构建

当源码仓库发生代码变动，需要重新执行工作流仓库的流水线。

![](https://object.innei.in/bed/2024/0501_1714563380454.png)

## 两个仓库

明确了上面的流程，我们现在就需要创建一个仓库专门供跑 CI 用，也就是上面说的工作流仓库。

然后我们，编写工作流配置。

```yaml {19-20,46}
name: Build and Deploy

on:
  push:
    branches:
      - main

jobs:
  build:
    name: Build artifact
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [20.x]
    steps:
      - uses: actions/checkout@v4
        with:
          repository: innei-dev/shiroi # 这里改成你的私有源码库
          token: ${{ secrets.GH_PAT }} # 这里需要你可以访问私有仓库的 Token
          fetch-depth: 0
          lfs: true

      - name: Checkout LFS objects
        run: git lfs checkout
      - uses: pnpm/action-setup@v2
      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'pnpm'
      - name: Install dependencies
        run: pnpm install
      - uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            ${{ github.workspace }}/.next/cache
          key: ${{ runner.os }}-nextjs-${{ hashFiles('**/pnpm-lock.yaml') }}-${{ hashFiles('**/*.js', '**/*.jsx', '**/*.ts', '**/*.tsx') }}
          restore-keys: |
            ${{ runner.os }}-nextjs-${{ hashFiles('**/pnpm-lock.yaml') }}-
      - name: Build project
        run: |
          sh ./ci-release-build.sh # 这里是你的构建脚本
```

上面的注释的地方需要注意。

## 构建和部署

### 构建和跨 Job 共享产物

接下来我们来写部署的工作配置。

在跨 Job 之间的产物共享，需要使用 Artifact。在构建的流程中，上传最后的产物作为 Artifact，然后在下一个 Job 中下载 Artifact 中使用。

```yaml
jobs:
  build:
    # ...
    - uses: actions/upload-artifact@v4
      with:
        name: dist # 上传名
        path: assets/release.zip # 源文件路径
        retention-days: 7

  deploy:
    name: Deploy artifact
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: dist # 下载上传的文件
```

> [!IMPORTANT]
> 使用这种方式会导致构建产物泄露，因为仓库是开源的，那么上传的产物任何人（登录 GitHub）都可以下载。
>
> People who are signed into GitHub and have read access to a repository can download workflow artifacts.

由于上面的方式并不安全，所以我们这里使用 CI cache 去实现相同的功能。

```yaml {4-9,25-31} expand
jobs:
  build:
    # ...
    - name: Cache Build Artifacts
      id: cache-primes
      uses: actions/cache/save@v4
      with:
        path: assets
        key: ${{ github.run_number }}-release # 使用 工作流序号 作为 key

  deploy:
    name: Deploy artifact
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Restore cached Build Artifacts
        id: cache-primes-restore
        uses: actions/cache/restore@v4
        with: # 还原产物
          path: |
            assets
          key: ${{ github.run_number }}-release
```

### 使用 SSH 传输产物到远程服务器

上面完成了产物的构建，接下来写部署到服务器的流程。

```yaml {17-62} expand
jobs:
  deploy:
    name: Deploy artifact
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Restore cached Build Artifacts
        id: cache-primes-restore
        uses: actions/cache/restore@v4
        with:
          path: |
            assets
          key: ${{ github.run_number }}-release
      - name: Move assets to root
        run: mv assets/release.zip release.zip

      - name: copy file via ssh password
        uses: appleboy/scp-action@v0.1.7
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USER }}
          password: ${{ secrets.PASSWORD }}
          key: ${{ secrets.KEY }}
          port: ${{ secrets.PORT }}
          source: 'release.zip'
          target: '/tmp/shiro'

      - name: Exec deploy script with SSH
        uses: appleboy/ssh-action@master

        with:
          command_timeout: 5m
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USER }}
          password: ${{ secrets.PASSWORD }}
          key: ${{ secrets.KEY }}
          port: ${{ secrets.PORT }}
          script_stop: true
          script: |
            set -e
            source $HOME/.bashrc
            basedir=$HOME/shiro
            workdir=$basedir/${{ github.run_number }}
            mkdir -p $workdir
            mv /tmp/shiro/release.zip $workdir/release.zip
            rm -r /tmp/shiro
            cd $workdir
            unzip -o $workdir/release.zip
            cp $HOME/shiro/.env $workdir/standalone/.env
            export NEXT_SHARP_PATH=$(npm root -g)/sharp
            # copy workdir ecosystem.config.js to basedir if not exists
            if [ ! -f $basedir/ecosystem.config.js ]; then
              cp $workdir/standalone/ecosystem.config.js $basedir/ecosystem.config.js
            fi
            # https://github.com/Unitech/pm2/issues/3054
            # symlink workdir node entry file to basedir
            ln -sf $workdir/standalone/server.js $basedir/server.js
            cd $basedir
            pm2 reload ecosystem.config.js --update-env
            rm $workdir/release.zip
            pm2 save
            echo "Deployed successfully"
```

这里我们使用 SSH + SCP 的方式把构建产物上传到服务器，然后直接相关的脚本。

我们使用 GitHub Workflow Id 作为当前的构建的标识，在服务器部署目录中进行区分。这样的话每次部署产物都存在服务器上，方便日后的回滚，虽然回滚的过程比较传统，但是你说实现没实现吧。

我这边是用 PM2 去托管项目，当然你可以使用其他的方式。

由于 PM2 并不能重载时更换程序的路径，所以这里我们使用了软链接的方式，通过修改软连接指向的版本路径即可。

```sh
 if [ ! -f $basedir/ecosystem.config.js ]; then
  cp $workdir/standalone/ecosystem.config.js $basedir/ecosystem.config.js
fi
# symlink workdir node entry file to basedir
ln -sf $workdir/standalone/server.js $basedir/server.js
```

而 `ecosystem.config.js` 是这样的。

```js {5}
module.exports = {
  apps: [
    {
      name: 'shiro',
      script: 'server.js', // 指向软连接
      autorestart: true,
      watch: false,
      max_memory_restart: '500M',
      env: {
        PORT: 2323,
        NODE_ENV: 'production',
        NEXT_SHARP_PATH: process.env.NEXT_SHARP_PATH,
      },
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
    },
  ],
}
```

## 回滚脚本

上一节通过软连接的方式，加之根据工作流序号去管理构建版本，让我们更好的进行回滚操作。

```sh
~/shiro$ ls
27  30  31  34  36  38  41  42  43  44  45  46  47  48  49  50  51  52  53  56  ecosystem.config.js  rollback.sh  server.js
```

现在我们的目录下存在很多个数字开头的构建产物。我们可以通过脚本去完成切换。

```sh filename="rollback.sh"
#!/bin/bash

# 用于存放数字文件夹的数组
folders=()

# 遍历当前目录下的文件和文件夹，将数字文件夹加入到数组中
for dir in *; do
  if [[ -d "$dir" && "$dir" =~ ^[0-9]+$ ]]; then
    folders+=("$dir")
  fi
done

# 数字文件夹按数字从大到小排序
IFS=$'\n' folders=($(sort -rn <<<"${folders[*]}"))
unset IFS

# 使用 select 构建一个选择菜单
echo "请选择一个文件夹进行操作："
select folder in "${folders[@]}"; do
  if [ -n "$folder" ]; then
    echo "您选择了文件夹：$folder"
    break
  else
    echo "无效的选择，请重新选择。"
  fi
done

# 检查用户所选的文件夹中是否存在文件 standalone/server.js
if [ -f "$folder/standalone/server.js" ]; then
  # 创建软链接到当前目录的 server.js
  ln -sf "$folder/standalone/server.js" server.js
  echo "已成功链接 $folder/standalone/server.js 到当前目录的 server.js"
  pm2 reload ecosystem.config.js --update-env
  echo "Rollback successfully."
else
  echo "错误：所选文件夹中不存在 standalone/server.js"
fi
```

上面的脚本由 GPT-4 编写，经过测试可用。

```sh
~/shiro$ bash rollback.sh
请选择一个文件夹进行操作：
 1) 56
 2) 53
 3) 52
 4) 51
 5) 50
 6) 49
 7) 48
 8) 47
 9) 46
10) 45
11) 44
12) 43
13) 42
14) 41
15) 38
16) 36
17) 34
18) 31
19) 30
20) 27
```

之后，切换软连接的指向，并 reload PM2。

```sh
lrwxrwxrwx 1 innei innei   41 May  2 13:59 server.js -> /home/innei/shiro/56/standalone/server.js
```

## 跨仓库调用工作流

当源码仓库有新的提交之后需要触发工作流仓库的重新执行流水线。

这里我们可以用 API 调用。

在源码仓库中，增加一个新的工作流。

```yaml {19-25} expand
name: Trigger Target Workflow

on:
  push:
    branches:
      - main

jobs:
  trigger:
    runs-on: ubuntu-latest

    steps:
      - name: Trigger Workflow in Another Repository
        run: |
          repo_owner="innei-dev"
          repo_name="shiroi-deploy-action"
          event_type="trigger-workflow"

          curl -L \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${{ secrets.PAT }}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/$repo_owner/$repo_name/dispatches \
            -d "{\"event_type\": \"$event_type\", \"client_payload\": {}}"
```

这里借助 GitHub API 调用工作流仓库的流水线重新执行。

然后需要修改被调用方的工作流配置：

```yaml {6-7}
on:
  push:
    branches:
      - main

  repository_dispatch:
    types: [trigger-workflow]

permissions: write-all
```

`types` 是调用方定义的，需要保持一致。

现在当源码触发到 `main` 的更新，就会通过 API 接口，调用起 `repository_dispatch` 中 `types` 相匹配的工作流。

![](https://object.innei.in/bed/2024/0501_1714562165538.png)

## 防止重复版本的构建

上面的配置基本已经可用，但是还有些地方我们需要判断下。

例如，相同的 commit 被认为是重复的，他应该只会被构建和推送部署一次。如果重复命中，应该跳过整个构建和部署流程。

这里我们利用每次的 commit hash 去判断，保存上次成功部署的 hash，和正在进行的 commit hash 比对，如果一致就跳过。

我们可以用文件的方式记录上次的 commit hash（你也可以用 artifact，至于为什么我使用文件请看下节的内容）。

我们把每次构建完成的 commit hash 保存在当前仓库下的 `build_hash` 文件下。

这里我们需要好几个流程去做这个事，首先读取当前仓库下的 `build_hash` 并保存在 `GITHUB_OUTPUT` 中供后续的流程读取。

然后下一个流程，检出源码仓库，读取源码仓库的 commit hash，和 `build_hash` 比对，输出一个 `boolean` 值，同样保存在 `GITHUB_OUTPUT` 中。

下一个流程，利用 `if` 直接判断是否应该退出整个流程（因为后续的流程都依赖这个，所以等于全部退出了）。

最后一个流程，在完成部署之后，保存当前的 commit hash 到 repo 中，我们使用了 Push action 去做。

然后因为这样导致每次 Bot 会 push 一个新的 commit，这个也不应该跑这个工作流。所以在第一个流程中 `if` 根据 commit message 去做下守卫。

参考配置如下：

```yaml {8,12,66,88-103,18} expand
name: Build and Deploy

on:
  push:
    branches:
      - main

permissions: write-all

env:
  HASH_FILE: build_hash

jobs:
  prepare:
    name: Prepare
    runs-on: ubuntu-latest
    if: ${{ github.event.head_commit.message != 'Update hash file' }}

    outputs:
      hash_content: ${{ steps.read_hash.outputs.hash_content }}

    - name: Read HASH_FILE content
      id: read_hash
      run: |
        content=$(cat ${{ env.HASH_FILE }}) || true
        echo "hash_content=$content" >> "$GITHUB_OUTPUT"


  check:
    name: Check Should Rebuild
    runs-on: ubuntu-latest
    needs: prepare
    outputs:
      canceled: ${{ steps.use_content.outputs.canceled }}

    steps:
      - uses: actions/checkout@v4
        with:
          repository: innei-dev/shiroi
          token: ${{ secrets.GH_PAT }}
          fetch-depth: 0
          lfs: true

      - name: Use content from prev job and compare
        id: use_content
        env:
          FILE_HASH: ${{ needs.prepare.outputs.hash_content }}
        run: |
          file_hash=$FILE_HASH
          current_hash=$(git rev-parse --short HEAD)
          echo "File Hash: $file_hash"
          echo "Current Git Hash: $current_hash"
          if [ "$file_hash" == "$current_hash" ]; then
            echo "Hashes match. Stopping workflow."
            echo "canceled=true" >> $GITHUB_OUTPUT
          else
            echo "Hashes do not match. Continuing workflow."
          fi


  build:
    name: Build artifact
    runs-on: ubuntu-latest
    needs: check
    if: ${{needs.check.outputs.canceled != 'true'}}

    # .... other build job config

  store:
    name: Store artifact commit version
    runs-on: ubuntu-latest
    needs: [deploy, build] # 依赖 build 和 deploy 流程
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          persist-credentials: false
          fetch-depth: 0

      - name: Use outputs from build
        env:
          SHA_SHORT: ${{ needs.build.outputs.sha_short }}
          BRANCH: ${{ needs.build.outputs.branch }}
        run: |
          echo "SHA Short from build: $SHA_SHORT"
          echo "Branch from build: $BRANCH"
      - name: Write hash to file
        env:
          SHA_SHORT: ${{ needs.build.outputs.sha_short }}

        run: echo $SHA_SHORT > ${{ env.HASH_FILE }}
      - name: Commit files
        run: |
          git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          git add ${{ env.HASH_FILE }}
          git commit -a -m "Update hash file"
      - name: Push changes
        uses: ad-m/github-push-action@master
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          branch: ${{ github.ref }}
```

## 永不会被禁用的 Cronjob 执行

为了能让这个工作流定时的去跑，可以使用 `schedule`:

```yaml {7-8}
name: Build and Deploy

on:
  push:
    branches:
      - main
  schedule:
    - cron: '0 3 * * *'

  repository_dispatch:
    types: [trigger-workflow]
```

由于 GitHub action 的限制，当一个仓库在 3 个月内没有活动时，工作流会被禁用。所以上一节中我们用了提交的方式去防止被禁用。在每次构建去上传 hash，也是一个很好的选择。

完事了，以上就是全部的内容了。

完整的配置在这里：

https://github.com/innei-dev/shiroi-deploy-action
