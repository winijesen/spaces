#!/bin/bash

echo "======================写入rclone配置========================"

# 启动 pm2（青龙）
echo "[INFO] 启动 pm2 服务..."
pm2 start /ql/docker/pm2.json
pm2 logs &

echo "======================3. 启动nginx========================"
nginx

echo "启动 code-server ..."
code-server --bind-addr 0.0.0.0:10000 --auth=none &

echo "启动青龙主程序..."
exec /ql/docker/docker-entrypoint.sh
