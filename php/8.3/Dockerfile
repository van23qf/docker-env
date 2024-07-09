FROM php:8.3-fpm

LABEL maintainer="qf19910623@gmail.com"

# 复制时区配置
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装基础
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    apt-utils \
    curl \
    sudo \
    iputils-ping \
    libicu-dev \
    libmemcached-dev \
    libz-dev \
    libpq-dev \
    libzip-dev \
    libonig-dev \
    libjpeg62-turbo-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libssl-dev \
    libmcrypt-dev \
    zlib1g-dev \
    libxml2-dev \
    libbz2-dev \
    librdkafka-dev \
    graphviz \
    git \
    vim \
    wget \
    net-tools \
    zip \
    unzip \
    openssh-server \
    openssh-client \
    subversion \
  && rm -rf /var/lib/apt/lists/*


# 安装PHP扩展
RUN docker-php-ext-configure bcmath --enable-bcmath \
    && docker-php-ext-configure pcntl --enable-pcntl \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql \
    && docker-php-ext-configure mbstring --enable-mbstring \
    && docker-php-ext-configure soap --enable-soap \
    && docker-php-ext-configure exif --enable-exif \
    && docker-php-ext-install \
        bcmath \
        intl \
        mbstring \
        mysqli \
        pcntl \
        pdo_mysql \
        sockets \
        zip \
        soap \
        exif \
  && docker-php-ext-install opcache \
  && docker-php-ext-enable opcache

RUN docker-php-ext-configure gd --with-jpeg=/usr/lib --with-freetype=/usr/include/freetype2 && docker-php-ext-install gd;

RUN pecl install -o -f redis && docker-php-ext-enable redis;

RUN pecl install -o -f mongodb && docker-php-ext-enable mongodb;

#RUN pecl install -o -f grpc && docker-php-ext-enable grpc;

RUN pecl install -o -f protobuf  && docker-php-ext-enable protobuf;

RUN pecl install -o -f memcached  && docker-php-ext-enable memcached;

RUN pecl install -o -f xlswriter  && docker-php-ext-enable xlswriter;

RUN pecl install -o -f rdkafka  && docker-php-ext-enable rdkafka;

RUN pecl install -o -f igbinary  && docker-php-ext-enable igbinary;

RUN pecl install -o -f swoole && docker-php-ext-enable swoole;

RUN rm -rf /tmp/pear

# 安装 Composer
ENV COMPOSER_HOME /usr/share/nginx/html/.composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer1
RUN composer1 config -g repo.packagist composer https://mirrors.aliyun.com/composer/ \
    && composer1 self-update --1

VOLUME $COMPOSER_HOME
WORKDIR /usr/share/nginx/html