# docker-env

一套可在多台服务器统一部署的 Docker 集成环境，集成 pgvector、MySQL、Redis、MinIO、Elasticsearch 等常用服务。所有数据、日志、配置统一存放在项目目录内，通过一份 `.env` 选择启用哪些容器，配合 `manage.sh` 实现一键启停。

## 特性

- **按需启用**：通过 `.env` 的 `ENABLED_SERVICES` 选择要启动的容器，互不干扰
- **数据集中**：所有数据/日志/配置 bind mount 到当前目录，便于备份与迁移
- **一键管理**：`manage.sh` 封装 `docker compose`，支持启动/停止/重启/日志/拉取镜像
- **健康检查**：每个服务都配置了 healthcheck，便于编排与监控
- **开箱即用**：pgvector 已自带 vector 扩展，MySQL 已配置 utf8mb4，Redis 已开启 AOF 持久化，Elasticsearch 已开启密码认证

## 目录结构

```
docker-env/
├── docker-compose.yml          # 服务定义 (带 profiles，按需启用)
├── manage.sh                   # 一键管理脚本
├── .env                        # 实际配置 (不提交 git)
├── .env.example                # 配置模板
├── conf/                       # 各服务配置文件
│   ├── pgvector/postgresql.conf
│   ├── mysql/my.cnf
│   ├── redis/redis.conf
│   └── elasticsearch/elasticsearch.yml
├── data/                       # 数据持久化 (不提交 git，属主为容器内用户)
│   ├── pgvector/
│   ├── mysql/
│   ├── redis/
│   ├── minio/
│   └── elasticsearch/
└── logs/                       # 日志持久化 (不提交 git)
    ├── pgvector/
    ├── mysql/
    ├── redis/
    ├── minio/
    └── elasticsearch/
```

## 环境要求

- Docker（建议 24+）
- Docker Compose v2（`docker compose` 子命令）
- Bash（管理脚本依赖）
- Elasticsearch 需要宿主机 `vm.max_map_count` 至少为 `262144`

## 快速开始

### 1. 准备配置

```bash
cp .env.example .env
# 编辑 .env，至少修改所有密码
```

`.env` 关键变量：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `ENABLED_SERVICES` | 启用的服务，空格分隔；可选 `pgvector mysql redis minio elasticsearch` | `pgvector mysql redis minio elasticsearch` |
| `COMPOSE_PROJECT_NAME` | 项目名，决定容器名/网络前缀 | `docker-env` |
| `POSTGRES_*` / `MYSQL_*` / `REDIS_*` / `MINIO_*` | 数据库和对象存储的库、用户、密码、端口 | 见 `.env.example` |
| `ELASTIC_PASSWORD` | Elasticsearch 内置 `elastic` 用户密码 | `change-me-please` |
| `ELASTICSEARCH_PORT` | Elasticsearch HTTP API 宿主机端口 | `9200` |
| `ELASTICSEARCH_MEMORY_LIMIT` | Elasticsearch 容器内存上限 | `1g` |

### 2. 启动

```bash
./manage.sh up
```

启动 `.env` 中 `ENABLED_SERVICES` 列出的全部服务。首次会自动拉取镜像。

### 3. 查看状态

```bash
./manage.sh ps
```

## 服务一览

| 服务 | 镜像 | 默认端口 | 说明 |
|------|------|----------|------|
| pgvector | `pgvector/pgvector:pg17` | 5432 | PostgreSQL 17 + vector 扩展 |
| mysql | `mysql:8.4` | 3306 | MySQL 8.4，utf8mb4 |
| redis | `redis:7-alpine` | 6379 | Redis 7，AOF 持久化 |
| minio | `minio/minio:latest` | 9000 / 9001 | S3 兼容对象存储（API / 控制台） |
| elasticsearch | `docker.elastic.co/elasticsearch/elasticsearch:9.4.3` | 9200 | 单节点，密码认证，HTTP |

连接信息（默认）：

- **pgvector**：`postgresql://postgres:<POSTGRES_PASSWORD>@<host>:5432/postgres`
- **MySQL**：`mysql -h<host> -P3306 -uroot -p<MYSQL_ROOT_PASSWORD>`
- **Redis**：`redis-cli -h<host> -p6379 -a<REDIS_PASSWORD>`
- **MinIO**：API `http://<host>:9000`，控制台 `http://<host>:9001`，凭据 `<MINIO_ROOT_USER>` / `<MINIO_ROOT_PASSWORD>`
- **Elasticsearch**：`curl -u elastic:<ELASTIC_PASSWORD> http://<host>:9200`

### 启用 vector 扩展（pgvector）

连接到 pgvector 后执行一次即可：

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 使用 Elasticsearch

Elasticsearch 以单节点模式运行，默认启用密码认证，但 HTTP 层未启用 TLS：

```bash
# 查看集群状态
curl -u "elastic:<ELASTIC_PASSWORD>" \
  "http://localhost:9200/_cluster/health?pretty"

# 查看 Elasticsearch 版本
curl -u "elastic:<ELASTIC_PASSWORD>" http://localhost:9200
```

Compose 将 9200 端口绑定到宿主机所有网卡。密码会通过明文 HTTP 传输，因此只能在可信内网中使用，并应通过防火墙或安全组阻止公网访问。

`ELASTIC_PASSWORD` 只在空数据目录首次初始化时设置内置用户密码。已有 `data/elasticsearch` 时，修改 `.env` 不会自动重置集群中的密码。

## 管理脚本用法

```bash
./manage.sh up [服务名...]        # 启动（默认启用 .env 中 ENABLED_SERVICES）
./manage.sh down [服务名...]      # 无参数=停止并移除全部；指定=仅停止对应容器
./manage.sh stop [服务名...]      # 停止容器（保留，不移除）
./manage.sh start [服务名...]     # 启动已存在的容器
./manage.sh restart [服务名...]   # 重启
./manage.sh ps                    # 查看状态
./manage.sh logs [服务名]         # 查看日志（跟踪输出，Ctrl+C 退出）
./manage.sh pull [服务名...]      # 拉取镜像
./manage.sh help                  # 查看用法
```

服务名取值：`pgvector`、`mysql`、`redis`、`minio`、`elasticsearch`。不传服务名时，`up`/`stop`/`start`/`restart`/`pull` 默认作用于 `.env` 中的 `ENABLED_SERVICES`。

### 示例

```bash
# 只启动 pgvector
./manage.sh up pgvector

# 重启 mysql 和 redis
./manage.sh restart mysql redis

# 查看 redis 日志
./manage.sh logs redis

# 只启动 Elasticsearch
./manage.sh up elasticsearch

# 停止全部并移除容器/网络（数据保留在 data/ 下）
./manage.sh down
```

## 部署到新服务器

1. 将本目录（不含 `data/`、`logs/`、`.env`）拷贝到目标服务器
2. `cp .env.example .env`，修改所有密码
3. `./manage.sh up`
4. 完成。数据会持久化到 `data/`，重启不丢失

## 数据与日志

- **数据目录** `data/<服务>/`：bind mount 到容器内对应路径，容器删除后数据保留
- **日志目录** `logs/<服务>/`：供服务写入日志文件；容器标准输出统一通过 `./manage.sh logs <服务>` 查看
- **配置目录** `conf/<服务>/`：自定义配置文件，挂载为只读

### 关于数据目录权限

各数据目录的文件属主可能是容器内服务用户，宿主机普通用户可能无权直接 `ls`/`cat`，这是正常的安全行为。

查看数据目录的正确方式：

```bash
# 方式1：进容器查看
docker exec docker-env-pgvector ls -la /var/lib/postgresql/data

# 方式2：用 docker 临时容器查看宿主机目录
docker run --rm -v "$(pwd)/data/pgvector:/d" alpine ls -la /d

# 方式3：sudo
sudo ls -la data/pgvector
```

> 不要为了"能 ls"去 `chmod`/`chown` 数据目录，可能导致服务拒绝启动。备份时使用 `docker exec ... pg_dump` / `mysqldump`，或停容器后 `sudo tar`。

Elasticsearch 官方容器使用 uid 1000。`manage.sh` 仅在首次创建 `data/elasticsearch` 时赋予初始化所需的写权限，不会修改 pgvector、MySQL、Redis、MinIO 的数据目录权限，也不会重复修改已存在的 Elasticsearch 数据目录。

### 关于日志目录权限

`manage.sh up` 会自动把 `logs/<服务>/` 设为 `1777`，以便容器内服务用户写入。若直接用 `docker compose up` 启动新服务，需先执行一次 `./manage.sh up` 让其建好目录权限，或手动 `chmod 1777 logs/<服务>`。

## 安全提醒

- `.env` 中的密码务必改为强密码，尤其是生产环境
- `.env`、`data/`、`logs/` 已在 `.gitignore` 中，不会被提交
- 建议通过防火墙/安全组限制数据库端口的外网访问
- Elasticsearch 当前使用密码认证但未启用 HTTPS，不要将 9200 端口暴露到公网

## 新增服务

参考 `docker-compose.yml` 中已有服务的写法：

1. 在 `docker-compose.yml` 添加服务块，带上 `profiles: ["<服务名>"]`
2. 在 `.env` / `.env.example` 补充该服务的变量
3. 在 `manage.sh` 的 `KNOWN_SERVICES` 列表中加入服务名
4. 在 `conf/<服务名>/` 放置配置文件（如该服务用独立配置文件）
5. `./manage.sh up <服务名>`
