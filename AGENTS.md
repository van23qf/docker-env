# AGENTS.md

本仓库是一个 Docker 集成环境（pgvector / mysql / redis / minio），无应用代码。改配置或脚本时务必读以下要点，多数坑都已踩过。

## 架构

- 单一 `docker-compose.yml`，每个服务带 `profiles: ["<服务名>"]`，未传 `--profile` 不会启动
- `manage.sh` 是唯一入口，封装 `docker compose`，读取 `.env` 的 `ENABLED_SERVICES` 转成 `--profile` 参数
- 数据/日志/配置全部 bind mount 到当前目录：`data/<svc>`、`logs/<svc>`、`conf/<svc>`

## 关键约定（容易踩坑）

### manage.sh 不 source .env
`.env` 中 `ENABLED_SERVICES=pgvector mysql redis` 含空格，若 `source` 会被 bash 当命令执行（曾导致 `ERROR 2002` mysql socket 报错）。脚本只用 `grep` 提取该变量；其余变量由 `docker compose` 自行读取 `.env`。**改动加载逻辑时保持这个方式。**

### down 无参数必须带全部 profile
`./manage.sh down`（无参）要用 `--profile pgvector --profile mysql --profile redis --profile minio` 调用 `docker compose down`，否则带 profile 的容器不会被移除。`KNOWN_SERVICES` 是硬编码的服务白名单，新增服务必须同步更新此变量，否则 `down`/校验会漏。

### 日志目录权限 1777
`logs/<svc>/` 必须是 `1777`，容器内服务用户（postgres/mysql/redis，uid 999）才能写入。`manage.sh up` 的 `ensure_dirs` 会自动 `chmod 1777`。**直接用 `docker compose up` 启动新服务不会自动设权限**，redis 曾因此 `FATAL CONFIG FILE ERROR: Can't open the log file` 反复重启。绕过 manage.sh 时需手动 `chmod 1777 logs/<svc>`。

### 数据目录权限不要改
`data/pgvector` 是 `0700`、属主 uid 999（PostgreSQL 强制），宿主机普通用户 `ls` 会报"权限不够"——**这是正常的，不是空的**。不要 `chmod`/`chown`，会导致 PG 拒绝启动。查看数据用：
```bash
docker exec docker-env-pgvector ls -la /var/lib/postgresql/data
```

## 常用命令

```bash
./manage.sh up [服务名...]       # 启动；无参=启用 .env 的 ENABLED_SERVICES
./manage.sh down                 # 停止并移除全部（必须无参才带全 profile）
./manage.sh restart pgvector     # 重启指定服务
./manage.sh ps                   # 状态
./manage.sh logs redis           # 跟踪日志（Ctrl+C 退出）
./manage.sh pull                 # 拉镜像
```

服务名仅限：`pgvector` `mysql` `redis` `minio`（`manage.sh` 会校验）。

## 验证改动

改 compose/脚本后：
```bash
docker compose --profile pgvector --profile mysql --profile redis --profile minio config --quiet   # 校验配置
bash -n manage.sh                                                                   # 校验脚本语法
./manage.sh down && ./manage.sh up && ./manage.sh ps                                 # 启停循环
```

健康检查全部 `healthy` 才算成功：
```bash
docker inspect --format='{{.State.Health.Status}}' docker-env-pgvector docker-env-mysql docker-env-redis docker-env-minio
```

## gitignore

`.env`、`data/`、`logs/` 不提交。`conf/` 提交。部署到新服务器需 `cp .env.example .env` 并改密码。

## 版本固定

- pgvector: `pgvector/pgvector:pg17`（升级 PG 大版本不能复用旧 data 目录，需清空 `data/pgvector` 重新初始化）
- mysql: `mysql:8.4`
- redis: `redis:7-alpine`
- minio: `minio/minio:latest`（未固定大版本；用环境变量配置，无独立配置文件，日志走 stdout 用 `docker logs` 查看）

## MinIO 说明

- 单节点单磁盘模式（`server /data`），适合本地/开发；生产需多节点纠删码
- 凭据用 `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` 环境变量，密码至少 8 位
- 两个端口：`9000` API、`9001` 控制台；数据落 `data/minio`，不写日志文件

## 当前密码（仅本地 .env，勿提交）

pgvector/mysql/redis 密码均为 `123456`，minio 密码 `12345678`，仅供本地测试。redis 密码经 `command --requirepass` 从 `REDIS_PASSWORD` 传入，不在 `conf/redis/redis.conf` 硬编码（该文件会提交 git）。
