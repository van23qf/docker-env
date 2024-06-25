FROM php:7.4-fpm

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

ARG EXT_GD
RUN if $EXT_GD; then \
    docker-php-ext-configure gd --with-jpeg=/usr/lib --with-freetype=/usr/include/freetype2 \
            && docker-php-ext-install gd; \
fi

ARG EXT_REDIS
RUN if $EXT_REDIS; then \
    pecl install -o -f redis && docker-php-ext-enable redis; \
fi

ARG EXT_GRPC
RUN if $EXT_GRPC; then \
    pecl install -o -f grpc && docker-php-ext-enable grpc; \
fi

ARG EXT_PROTOBUF
RUN if $EXT_PROTOBUF; then \
    pecl install -o -f protobuf  && docker-php-ext-enable protobuf; \
fi

ARG EXT_MEMCACHED
RUN if $EXT_MEMCACHED; then \
    pecl install -o -f memcached  && docker-php-ext-enable memcached; \
fi

ARG EXT_SWOOLED
RUN if $EXT_SWOOLED; then \
    pecl install -o -f https://pecl.php.net/get/swoole-4.8.11.tgz && docker-php-ext-enable swoole; \
fi

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