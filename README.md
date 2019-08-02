# SJay3_microservices
SJay3 microservices repository

[![Build Status](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices)

## Homework 12 (docker-2)
В данном домашнем задании было сделано:
- Установка докера
- Основные команды докера
- Обяснить отличия образа от контейнера (*)
- Подготовка GCP
- Работа с Docker-Machine
- Создание структуры репозитория
- Создание Dockerfile
- Сборка и запуск контейнера

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

### Подготовка GCP

Необходимо подготовить GCP для нашего проекта с микросервисами.
Создадим в GCP новый проект с название docker. Далее перейдем в web-интерфейсе в Compute Engine для того, что бы гугл инициализировал управление виртуальными машинами. Выполним команду инициализации gcloud:

```shell
# Заного инициализируем gcloud и выберем создание новой конфигурации, т.к. в конфигурации default у нас настроен проект infra
gcloud init

# назовем конфигурацию docker. Выберем созданный нами проект docker, а так же зададим дефолтную зону по умолчанию

# Проверим, что конфигурация создалась с правильными параметрами
gcloud config configurations list

# Переключение между конфигурациями
gcloud config configurations activate <имя конфигурации>

```

### Работа с Docker-Machine

Docker-machine - это встроенный в докер механизм для создания хостов и установки на них docker engine (server).

Команда создания - `docker-machine create <имя>`. Имен может быть много, переключение между ними через `eval $(docker-machine env <имя>)`. Переключение на локальный докер - `eval $(docker-machine env --unset)`. Удаление - `docker-machine rm <имя>`.
docker-machine создает хост для докер демона со указываемым образом в `--googlemachine-image`, в ДЗ используется ubuntu-16.04. Образы которые используются для построения докер контейнеров к этому никак не относятся.
Все докер команды, которые запускаются в той же консоли после `eval $(docker-machine env <имя>)` работают с удаленным докер демоном в GCP.

#### Установка docker-machine

[Ссылка на установку для Linux](https://docs.docker.com/machine/install-machine/)

Для Windows и MacOS Docker-Machine идет в комплекте.

#### Создание удаленного хоста с docker

Выполним команду:

```shell
export GOOGLE_PROJECT=docker-248611
docker-machine create --driver google \
--google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
--google-machine-type n1-standard-1 \
--google-zone europe-west1-b \
docker-host
```

Проверим, что наш хост успешно создан:

```shell
docker-machine ls
```

Переключимся на удаленный хост:

```shell
eval $(docker-machine env docker-host)
```

Теперь все дальнейшие команды docker будут выполняться на удаленном хосте.

### Создание структуры репозитория

В директории docker-monolith создадим 4 файла:
- Dockerfile - описание нашего докер-образа
- mongod.conf - подготовленный конфиг для mongo
- db_config - файл с переменной окружения адреса БД
- start.sh - файл запуска приложения

### Создание Dockerfile

Dockerfile всегда должен начинаться с инструкции FROM (единственная инструкция, которая может быть указана до FROM - это ARG)

Запишем в докерфайл наш базовый образ, на котором будем строить свой:

```Dockerfile
FROM ubuntu:16.04
```

Далее напишем установку необходимых пакетов, ruby и mongo:

```Dockerfile
RUN apt-get update
RUN apt-get install -y mongodb-server ruby-full ruby-dev build-essential git
RUN gem install bundler
```

Скачаем наше приложение в контейнер:

```Dockerfile
RUN git clone -b monolith https://github.com/express42/reddit.git
```

Скопируем файлы конфигурации в контейнер:

```Dockerfile
COPY mongod.conf /etc/mongod.conf
COPY db_config /reddit/db_config
COPY start.sh /start.sh
```

Установим зависимости приложения и сделаем скрипт запуска выполняемым:

```Dockerfile
RUN cd /reddit && bundle install
RUN chmod 0777 /start.sh
```

Добавим запуск сервиса при старте контейнера:

```Dockerfile
CMD ["/start.sh"]
```

### Сборка и запуск контейнера

Для сборки нашего образа перейдем в папку docker-monolith где находится наш докерфайл и выполним команду:

```shell
docker build -t reddit:latest .
```

Ключ `-t` задает тег для нашего образа. Точка в конце команды указывает, что сборочный контекст находится в текущей директории.

Для просмотра всех образов (в том числе и промежуточных), необходимо выполнить команду:

```shell
docker images -a
```

Запустим контейнер командой:

```shell
docker run --name reddit -d --network=host reddit:latest
```

Ключ `--name` задает имя контейнера. Ключ `-d` запускает контейнер в бекграунде. Ключ `--network=host` задает тип сети для контейнера

Т.к. мы не настроили правила фаервола в для порта 9292 в GCP, необходимо это сделать с помощью команды:

```shell
gcloud compute firewall-rules create reddit-app \
--allow tcp:9292 \
--target-tags=docker-machine \
--description="Allow PUMA connections" \
--direction=INGRESS
```

С помощью команды `docker-machine ls` узнаем ip нашего хоста и попробуем открыть в браузере наше приложение по адресу хоста и порту 9292. 
