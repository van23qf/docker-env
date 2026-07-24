#!/usr/bin/env bash
# ============================================================
# Docker 集成环境管理脚本
# 用法:
#   ./manage.sh up [服务名...]        启动 (默认启动 .env 中 ENABLED_SERVICES)
#   ./manage.sh down [服务名...]      停止并移除 (无参数=全部 down，指定=仅 stop)
#   ./manage.sh stop [服务名...]      停止容器 (保留，不移除)
#   ./manage.sh start [服务名...]     启动已存在的容器
#   ./manage.sh restart [服务名...]   重启
#   ./manage.sh ps                    查看状态
#   ./manage.sh logs [服务名]         查看日志 (跟踪输出，Ctrl+C 退出)
#   ./manage.sh pull [服务名...]      拉取镜像
#   ./manage.sh status                同 ps
# 服务名可选: pgvector mysql redis minio elasticsearch
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 已知服务列表 (用于校验与提示)
KNOWN_SERVICES="pgvector mysql redis minio elasticsearch"

# 从 .env 安全读取 ENABLED_SERVICES (不 source，避免 .env 内容被执行)
# 其他变量由 docker compose 自行读取当前目录 .env
if [ -f .env ]; then
  ENABLED_SERVICES="$(grep -E '^ENABLED_SERVICES=' .env 2>/dev/null | head -1 | cut -d= -f2- | sed "s/^[\"']//; s/[\"']$//")"
fi
ENABLED_SERVICES="${ENABLED_SERVICES:-}"
COMPOSE="docker compose"

# ---------- 辅助函数 ----------

# 校验服务名是否合法
validate_services() {
  local svc
  for svc in "$@"; do
    if ! echo " $KNOWN_SERVICES " | grep -q " $svc "; then
      echo "错误: 未知服务 '$svc'，可选: $KNOWN_SERVICES" >&2
      exit 1
    fi
  done
}

# 为给定服务列表生成 --profile 参数
build_profiles() {
  local svc args=""
  for svc in "$@"; do
    args="$args --profile $svc"
  done
  echo "$args"
}

# 确保数据/日志/配置目录存在，并给日志目录放宽权限
ensure_dirs() {
  local svc data_dir
  for svc in "$@"; do
    data_dir="data/$svc"
    if [ ! -d "$data_dir" ]; then
      mkdir -p "$data_dir"
      if [ "$svc" = "elasticsearch" ]; then
        # 官方镜像以 uid 1000 运行；新建的 bind mount 必须允许其初始化数据。
        chmod 0777 "$data_dir"
      fi
    fi
    mkdir -p "logs/$svc" "conf/$svc"
    # 日志目录需要被容器内服务用户写入 (postgres uid=999 等)
    chmod 1777 "logs/$svc" 2>/dev/null || true
  done
}

# 解析目标服务: 无参数则用 ENABLED_SERVICES
resolve_services() {
  if [ "$#" -gt 0 ]; then
    validate_services "$@"
    echo "$*"
  else
    if [ -z "$ENABLED_SERVICES" ]; then
      echo "错误: 未指定服务，且 .env 未配置 ENABLED_SERVICES" >&2
      exit 1
    fi
    echo "$ENABLED_SERVICES"
  fi
}

# ---------- 子命令 ----------

cmd_up() {
  local services
  services="$(resolve_services "$@")"
  validate_services $services
  ensure_dirs $services
  local profiles
  profiles="$(build_profiles $services)"
  echo "==> 启动服务: $services"
  $COMPOSE $profiles up -d
}

cmd_down() {
  if [ "$#" -gt 0 ]; then
    validate_services "$@"
    echo "==> 停止服务: $*"
    $COMPOSE stop "$@"
  else
    local profiles
    profiles="$(build_profiles $KNOWN_SERVICES)"
    echo "==> 停止并移除全部容器/网络"
    $COMPOSE $profiles down
  fi
}

cmd_stop() {
  local services
  services="$(resolve_services "$@")"
  validate_services $services
  echo "==> 停止服务: $services"
  $COMPOSE stop $services
}

cmd_start() {
  local services
  services="$(resolve_services "$@")"
  validate_services $services
  echo "==> 启动服务: $services"
  $COMPOSE start $services
}

cmd_restart() {
  local services
  services="$(resolve_services "$@")"
  validate_services $services
  echo "==> 重启服务: $services"
  $COMPOSE restart $services
}

cmd_ps() {
  $COMPOSE ps -a
}

cmd_logs() {
  if [ "$#" -gt 0 ]; then
    validate_services "$1"
    $COMPOSE logs --tail=200 -f "$1"
  else
    $COMPOSE logs --tail=200 -f
  fi
}

cmd_pull() {
  local services profiles
  services="$(resolve_services "$@")"
  validate_services $services
  profiles="$(build_profiles $services)"
  echo "==> 拉取镜像: $services"
  $COMPOSE $profiles pull
}

usage() {
  sed -n '2,18p' "$0"
}

# ---------- 入口 ----------

case "${1:-}" in
  up)        shift; cmd_up "$@" ;;
  down)      shift; cmd_down "$@" ;;
  stop)      shift; cmd_stop "$@" ;;
  start)     shift; cmd_start "$@" ;;
  restart)   shift; cmd_restart "$@" ;;
  ps|status) shift; cmd_ps "$@" ;;
  logs)      shift; cmd_logs "$@" ;;
  pull)      shift; cmd_pull "$@" ;;
  -h|--help|help) usage ;;
  "") echo "错误: 缺少子命令。运行 ./manage.sh help 查看用法" >&2; exit 1 ;;
  *) echo "错误: 未知命令 '$1'。运行 ./manage.sh help 查看用法" >&2; exit 1 ;;
esac
