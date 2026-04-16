#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-04-17-TEST 🔥🔥🔥"

export PATH="$HOME/bin:$PATH"

dir_shell=/ql/shell
. $dir_shell/share.sh

echo -e "======================写入rclone配置========================\n"
mkdir -p /home/coder/.config/rclone
echo "$RCLONE_CONF" > /home/coder/.config/rclone/rclone.conf

export_ql_envs() {
  export BACK_PORT="${ql_port}"
  export GRPC_PORT="${ql_grpc_port}"
}

log_with_style() {
  local level="$1"
  local message="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "\n[%s] [%7s]  %s\n" "${timestamp}" "${level}" "${message}"
}

# DNS 修复（Alpine）
if [ -f /etc/alpine-release ]; then
  if ! grep -q "^options ndots:0" /etc/resolv.conf 2>/dev/null; then
    echo "options ndots:0" >> /etc/resolv.conf
    log_with_style "INFO" "🔧  已配置 DNS 解析优化 (ndots:0)"
  fi
fi

log_with_style "INFO" "🚀  1. 检测配置文件..."
load_ql_envs
export_ql_envs
. $dir_shell/env.sh
import_config "$@"
fix_config

###############################################
# ⭐⭐ 让青龙监听 Render 注入的 PORT ⭐⭐
###############################################
echo "Render PORT = $PORT"

# 如果 PORT 为空，给出提示（Render 必须注入）
if [ -z "$PORT" ]; then
  echo "❌ Render 没有注入 PORT，青龙无法监听正确端口"
else
  echo "✔ Render 注入的 PORT = $PORT"
fi

# 修改青龙 .env 的端口
if [ -f "$QL_DIR/.env" ]; then
  sed -i "s/^PORT=.*/PORT=$PORT/" "$QL_DIR/.env"
  echo "✔ 已将青龙监听端口改为：$PORT"
else
  echo "⚠️ 找不到 $QL_DIR/.env，无法修改端口"
fi
###############################################

# PM2 初始化
pm2 l &>/dev/null || log_with_style "WARN" "PM2 初始化失败，将在启动时尝试备用方案"

log_with_style "INFO" "⚙️  2. 启动 pm2 服务..."
reload_pm2

# ⭐ 关闭原镜像自带的 code-server（它会在 pm2 启动青龙后自动启动）
pkill -f "code-server" 2>/dev/null

# bot
if [[ $AutoStartBot == true ]]; then
  log_with_style "INFO" "🤖  启动 bot..."
  nohup ql bot >$dir_log/bot.log 2>&1 &
fi

# extra
if [[ $EnableExtraShell == true ]]; then
  log_with_style "INFO" "🛠️  执行自定义脚本..."
  nohup ql extra >$dir_log/extra.log 2>&1 &
fi

log_with_style "SUCCESS" "🎉  容器启动成功!"

echo -e "======================3. 启动nginx========================\n"

###############################################
# ⭐⭐ 检查 envsubst 是否存在（完整上下文）⭐⭐
###############################################
echo "=== 检查 envsubst 是否存在 ==="        # ←⭐ 标记1
which envsubst || echo "which 找不到 envsubst"   # ←⭐ 标记2
envsubst --version || echo "envsubst 无法执行"    # ←⭐ 标记3
echo "=== 检查结束 ==="                     # ←⭐ 标记4
###############################################

# ⭐ 替换 Render 的 PORT 环境变量
echo "替换 Render 的 PORT 环境变量..."
envsubst '$PORT' < /etc/nginx/conf.d/front.conf > /etc/nginx/conf.d/front_render.conf
mv /etc/nginx/conf.d/front_render.conf /etc/nginx/conf.d/front.conf

# ⭐ 启动 nginx
nginx -s reload 2>/dev/null || nginx -c /etc/nginx/nginx.conf
echo -e "nginx启动成功...\n"

echo -e "##########写入登陆信息############"
dir_root=/ql && source /ql/shell/api.sh 

init_auth_info() {
  local body="$1"
  local tip="$2"
  local currentTimeStamp=$(date +%s)
  local api=$(
    curl -s --noproxy "*" "http://0.0.0.0:5700/api/user/init?t=$currentTimeStamp" \
      -X 'PUT' \
      -H "Content-Type: application/json;charset=UTF-8" \
      --data-raw "{$body}"
  )
  code=$(echo "$api" | jq -r .code)
  message=$(echo "$api" | jq -r .message)
  if [[ $code == 200 ]]; then
    echo -e "${tip}成功🎉"
  else
    echo -e "${tip}失败(${message})"
  fi
}

init_auth_info "\"username\": \"$ADMIN_USERNAME\", \"password\": \"$ADMIN_PASSWORD\"" "Change Password"

# rclone 同步
if [ -n "$RCLONE_CONF" ]; then
  echo -e "##########同步备份############"
  OUTPUT=$(rclone ls "$REMOTE_FOLDER" 2>&1)
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    if [ -z "$OUTPUT" ]; then
      echo "初次安装"
    else
      mkdir /ql/.tmp/data
      rclone sync $REMOTE_FOLDER /ql/.tmp/data && real_time=true ql reload data
    fi
  else
    echo "错误：$OUTPUT"
  fi
else
  echo "没有检测到Rclone配置信息"
fi

# 通知
if [ -n "$NOTIFY_CONFIG" ]; then
  python /notify.py
  sleep 60 && source /ql/shell/api.sh && notify_api '青龙服务启动通知' '青龙面板成功启动'
else
  echo "没有检测到通知配置信息，不进行通知"
fi

echo "启动 code-server ..."

rm -rf /home/coder/.config/code-server
mkdir -p /home/coder/.config/code-server

cat > /home/coder/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:10001
auth: none
EOF

nohup code-server --config /home/coder/.config/code-server/config.yaml &

echo "青龙主程序已由 reload_pm2 启动，无需重复启动"

pm2 logs


