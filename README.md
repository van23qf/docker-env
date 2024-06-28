# docker-env

自己用的lnmp docker环境

## 构建容器
```
docker-compose up -d --build [容器名称]
```
## 运行某个版本的php命令
```
docker-compose exec php74 php -m
```

## 进入某个容器的终端
```
docker-compose exec -it [容器名称] bash
```