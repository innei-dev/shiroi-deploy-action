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
