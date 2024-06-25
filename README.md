# docker-env

自己用的lnmp docker环境

## 构建容器
```
docker-compose up -d --build [服务名称]
```
## 运行某个版本的php命令
```
docker-compose exec php74 php -m
```