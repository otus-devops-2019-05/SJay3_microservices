# SJay3_microservices
SJay3 microservices repository

[![Build Status](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices)

## Homework 12 (docker-2)
В данном домашнем задании было сделано:
- Установка докера
- Основные команды докера
- Обяснить отличия образа от контейнера (*)

### Установка докера

Установка производится по следующим инструкциям:
- [Для Linux (ubuntu)](https://docs.docker.com/install/linux/docker-ce/ubuntu/)
- [Для MacOS](https://docs.docker.com/docker-for-mac/install/)
- [Для Windows](https://docs.docker.com/docker-for-windows/install/)

Установим докер по инструкции для ubuntu.
После устаноки, необходимо произвести post-installation шаги: https://docs.docker.com/install/linux/linux-postinstall/

### Основные команды докера

Версия докера:

```shell
docker version
```

Список запущенных контейнеров:

```shell
docker ps
```

Список всех контейнеров:

```shell
docker ps -a
```

Список сохраненных образов:

```shell
docker images
```

Запуск контейнеров:

```shell
docker run
```

Запуск нового контейнера в интерактивном режиме с выполнением команды `/bin/bash`:

```shell
docker run -it ubuntu:16.04 /bin/bash
```

Если указать ключ `--rm` при запуске контейнера, то после остановки контейнер удалится.

Запуск ранее созданного, но остановленного контейнера:

```shell
docker start <container_id>
```

Подключение к запущенному контейнеру:

```shell
docker attach <container_id>
```

Для того, что бы выйти из контейнера не убивая его, необходимо последовательно нажать `Ctrl + p, Ctrl + q`

Запуск еще одного процесса bash внутри работающего контейнера:

```shell
docker exec -it <container_id> bash
```

Для создания образа (image) из контейнера используется комманда:

```shell
docker commit <container_id> <yourName>/<imageName>
```

Команда `docker kill` посылает сигнал SIGKILL контейнеру.
Команда `docker stop` послывает сигнал SIGTERM контейнеру, а через 10 секунд посылает SIGKILL

Команда `docker system df` отображает сколько дискового пространства занято контейнерами, образами и вольюмами, а так же сколько из них не используется и возможно удалить.

Для удаления контейнера используется команда:

```shell
docker rm <container_id>
```

При указании ключа `-f` можно удалять работающий контейнер.

Для удаления образа используется команда:

```shell
docker rmi <image_id>
```

```shell
# Удалить все незапущенные контейнеры
docker rm $(docker ps -a -q)
# Удалить все образы
docker rmi $(docker images -q)
```

### Обяснить отличия образа от контейнера (*)

Необходимо сравнить вывод команды `docker inspect <container_id>` и `docker inspect <image_id>`. Записать объяснение чем отличается образ от контейнера в файл `docker-monolith/docker-1.log`


