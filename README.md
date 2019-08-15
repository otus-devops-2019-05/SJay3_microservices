# SJay3_microservices
SJay3 microservices repository

[![Build Status](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices)

## Homewokr 15 (gitlab-ci-1)
В данном домашнем задании было сделано:
- Установка Gitlab в докере
- Настройка Gitlab
- Настройка Gitlab CI/CD Pipeline
- Тестирование reddit

### Установка Gitlab в докере
#### Подготовка инфраструктуры
В одном из предыдущих домашних заданий было задание со звездочкой на создание инстанса с докером. Для развертывания инфраструктуры будем использовать эти наработки.
Добавим в конфигурацию терраформа переменные `docker_disk_size` со значением по умолчанию 10, а так же переменную `enable_web_traffic` для управления созданием ресурса фаервола, которая может иметь значения true/false.
В main.tf добавим использование переменной `docker_disk_size` в определение загрузочного диска. Так же, создадим ресурс `google_compute_firewall.docker_http` который будет разрешать http/https трафик для нашего инстанса. Так же добавим в него строку `count = "${var.enable_web_traffic ? 1 : 0}"` Которая означает, что если переменная `enable_web_traffic` установалена в true, то ресурс будет создаваться, а если false, то нет.

Определим переменные в файле terraform.tfvars.

Конфигурация пакера для создания образа с докером у нас уже создана, как и провижининг через ансибл, поэтому нам остается только выполнить команду:

```shell
cd docker-monolith/infra/terraform
terraform apply
```

#### Запуск GitlabCi в докере

Перед началом запуска гитлаба в докер-контейнере, необходимо подготовить окружение. Логинимся на созданную машину по ssh и выполняем команды от рута:

```shell
sudo su
mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
cd /srv/gitlab
touch docker-compose.yml
```

Файл docker-compose.yml

```yaml
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'http://<YOUR-VM-IP>'
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
```

Теперь запускаем контейнер с гитлабом

```shell
docker-compose up -d
```

### Настройка Gitlab
Теперь откроем в браузере http://<docker-host-ip>, и гитлаб предложит изменить нам пароль от встроенного пользователя root.
Далее, залогинимся и перейдем в глобальные настройки. Там выбираем settings -> Sign-up restrictions и снимаем галочку с sign-up enabled.

Теперь создадим группу homework, а внутри неё создадим репозиторий example.

Добавим наш созданный репозиторий в remotes нашего репозитория с микросервисами и сделаем пуш:

```shell
git checkout -b gitlab-ci-1
git remote add gitlab http://<docker-host-ip>/homework/example.git
git push gitlab gitlab-ci-1
```

!! ВАЖНО. На Windows это почему-то не работает. При добавлении remote через WSL и следующим пуше гитлаб возвращает 503 ошибку. Через SourceTree выдается тоже самое. При этом в linux все отработало нормально. Не ясно с чем это связано.

### Настройка Gitlab CI/CD Pipeline
В корне репозитория создадим тестовый файл `.gitlab-ci.yml`, в котором опишем используемые stages и тестовые джобы.

Сохраняем файл и пушим в репозиторий гитлаба:

```shell
git add .gitlab-ci.yml
git commit -m "add pipeline definition"
git push gitlab gitlab-ci-1
```

Зайдем в гитлаб в наш репозиторий в CI/CD -> Pipelines и увидим, что пайплайн готов, но в статусе pending, т.к. у нас нет ранера
В репозитории идем в settings -> CI/CD -> Runner settings и находим токен для ранера. Запоминаем его - он понадобится для регистрации ранера.

Теперь сделаем ранер. На сервере где запущен контейнер с гитлабом выполним команду:

```shell
docker run -d --name gitlab-runner --restart always \
-v /srv/gitlab-runner/config:/etc/gitlab-runner \
-v /var/run/docker.sock:/var/run/docker.sock \
gitlab/gitlab-runner:latest
```

После запуска контейнера зарегистрируем ранер:

```shell
root@gitlab-ci:~# docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false
Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):
http://<YOUR-VM-IP>/
Please enter the gitlab-ci token for this runner:
<TOKEN>
Please enter the gitlab-ci description for this runner:
[38689f5588fe]: my-runner
Please enter the gitlab-ci tags for this runner (comma separated):
linux,xenial,ubuntu,docker
Please enter the executor:
docker
Please enter the default Docker image (e.g. ruby:2.1):
alpine:latest
Runner registered successfully.
```

Теперь можно убедиться что пайплайн заработал и выполняется.

### Тестирование reddit
Добавим приложение reddit в наш репозиторий

```shell
git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
git add reddit/
git commit -m “Add reddit app”
git push gitlab gitlab-ci-1
```

----
## Homework 14 (docker-4)
В данном домашнем задании было сделано:
- Работа с сетью Docker
- Работа с docker compose
- Переопределение docker-compose.yml (*)

### Работа с сетью Docker
Основные драйверы для работы с сетью в докере:
- none
- host
- macvlan
- bridge
- overlay

Рассмотрим некоторые из них.

#### Dirver none
Этот драйвер означает, что у контейнера не будет никаких внешних сетевых интерфейсов. Только loopback.

Выполним команду, что бы проверить это:

```shell
docker run -it --rm --network none joffotron/docker-net-tools -c ifconfig
```

#### Driver host
При использовании этого драйвера, контейнер подключается напрямую к хосту. Т.е. контейнер использует network namespace хоста. В данном режиме сеть не управляется докером, контейнер будет иметь тот же адрес, что и докер-хост, и 2 разных сервиса в разных контейнерах не смогут слушать один и тот же порт.

Это самый производительный режим сетевого драйвера (в части сетевых задержек).

Выполним команду для проверки сетевых интерфейсов внури контейнера, и команду для проверки сетевых интерфейсов на докер-хосте:

```shell
# Проверим сетевые интерфейсы внутри контейнера
docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig

# Проверим сетевые интерфейсы на докер-хосте
docker-machine ssh docker-host ifconfig
```

Данные от этих 2-х команд в данном случае будут одинаковыми, т.к., как уже было сказано, контейнер подключается напрямую к к сетевому неймспейсу хоста.

#### Driver bridge
Этот драйвер используется по умолчанию при запуске контейнеров. При использовании этого драйвера в хост-системе создается мост между интерфейсов хоста и виртуальным интерфесом. Виртуальный интерфейс контейнера подключается к мосту и весь трафик будет ходить через него. Так же, докер управляет правилами iptables, в которых помимо фильтрации трафика выполняет NAT при обращении к контейнеру или из контейнера наружу.

!! Важно. Докер-сеть с драйвером bridge (docker0) создаается по умолчанию при установке докера, но данная сеть не поддерживает service discovery, а значит через встроенные средства докер у контейнеров не получится общаться друг с другом через имена (только через ip адреса).

Пример работы с bridge драйвером мы выполняли в прошлом [домашнем заданнии](#сборка-и-запуск-приложени-в-контейнерах)

Рассмотрим более сложный пример. Создадим 2 подсети:
- back_net
- front_net

В подсети back_net мы разместим контейнер с базой.
В подсети front_net мы разместим контейнер ui.
Оставшиеся 2 контейнера comment и post должны взаимодействовать сразу с 2-мя подсетями. 

```shell
# создадим подсети
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24

# Запустим конетйнеры
docker run -d --network=front_net -p 9292:9292 --name ui  sjotus/ui:1.0
docker run -d --network=back_net --name comment  sjotus/comment:1.0
docker run -d --network=back_net --name post  sjotus/post:1.0
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest

# При запуске контейнера докер может покдючить к нему только 1 сеть, поэтому дополнительно подключим вторую сеть к контейнерам post и comment

docker network connect front_net post
docker network connect front_net comment
```

### Работа с docker compose
#### Установка docker compose
Инструкции по установке:
- MacOS (идет в комплекте): https://docs.docker.com/docker-for-mac/install/
- Windows (идет в комплекте): https://docs.docker.com/docker-for-windows/install/
- Linux: https://docs.docker.com/compose/install/#install-compose

Для Linux так же можно использовать команду:

```shell
pip install docker-compose
```

#### docker-compose. Основные команды.

```shell
# поднятие контейнеров
docker-compose up
# поднятие контейнеров в режиме detach
docker-compose up -d
# команда up скачивает недостающие образы или собирает образ из докер файла, после чего запускает его

# Остановка и удаление контейнера
docker-compose down

# Запуск и остановка контейнеров
docker-compose start
docker-compose stop
# start запускает ранее остановленные контейнеры. Stop просто останавливает контейнеры без их удаления

# Просмотр информации о работе compose
docker-compose ps

```

Docker-compose поддерживает интерполяцию переменных окружения. Так же, поддерживает автоматическую загрузку переменных из файла с расширением `.env`

#### Именование проекта в docker-compose
По-умолчанию докер композ составляет имена запущеных контейнеров по следующей схеме:

```
БазовоеИмяПроекта_ИмяСервиса_НомерИнстанса
```

`БазовоеИмяПроекта` по-умолчанию определяется как имя каталога, в котором находится docker-compose.yml. Это имя можно изменить, при запуске композа:

```shell
# start compose
docker-compose -p <БазовоеИмяПроекта> up

# Stop compose
docker-compose -p <БазовоеИмяПроекта> down
```

Либо задав переменную окружения `COMPOSE_PROJECT_NAME`

### Переопределение docker-compose.yml (*)
Стандарно при выполнении команды `docker-compose up` композ ищет 2 файла: `docker-compose.yml` и `docker-compose.override.yml`. Если он находит оба, то мержит их в один (обычно override перезаписывает стандартный файл) по [правилам](https://docs.docker.com/compose/extends/#adding-and-overriding-configuration)

Создадим файл `docker-compose.override.yml`, который позволит:
- Изменять код каждого из приложений, не выполняя сборку образа
- Запускать puma для руби приложений в дебаг режиме с двумя воркерами (флаги --debug и -w 2)

Поскольку мы используем bind для подключения папок в override файле, то папки с содержимым должны существовать на удаленном хосте docker-host, либо следует запускать композ локально.



----
## Homework 13 (docker-3)
В данном домашнем задании было сделано:
- Сборка и запуск приложений в контейнерах
- Запуск контейнеров с другими сетевыми алиасами (*)
- Опитмизация докер-образов (*)
- Подключение вольюма к контейнеру

### Сборка и запуск приложений в контейнерах
Скачаем исходные коды приложения и положим их в корень нашего репозитория в папку src. Таким образом у нас получится структура:
- src/post-py
- src/comment
- src/ui

Каждая из этих директорий является сервисом и будет превращена в контейнер, поэтому напишем докерфайлы к каждому сервису.

Сборку будем производить на удаленном хосте docker-host, который мы создавали в прошлый [раз](#Создание-удаленного-хоста-с-docker)

Подключимся к хосту, скачаем последний образ монги и выполним команды сборки образов:

```shell
eval $(docker-machine env docker-host)
docker pull mongo:latest
docker build -t <your-dockerhub-login>/post:1.0 ./post-py
docker build -t <your-dockerhub-login>/comment:1.0 ./comment
docker build -t <your-dockerhub-login>/ui:1.0 ./ui
```

Теперь создадим сеть и запустим контейнеры:

```shell
docker network create reddit
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post sjotus/post:1.0
docker run -d --network=reddit --network-alias=comment sjotus/comment:1.0
docker run -d --network=reddit -p 9292:9292 sjotus/ui:1.0
```

Теперь для проверки работоспособности можно зайти на http://<docker-host_ip>:9292

### Запуск контейнеров с другими сетевыми алиасами (*)

Т.к. взаимодействие между контейнерами организовано через ENV переменные записанные в докерфайле, то для того, что бы контейнеры могли взаимодействовать через новые алиасы эти переменные необходимо переопределить при запуске контейнера с помощью ключа `--env`. Более подробно, а так же другие варианты задания переменных при запуске можно посмотреть в [официальной документации](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file)

Остановим все контейнеры:

```shell
docker kill $(docker ps -q)
```

И запустим с новыми алиасами

```shell
docker run -d --network=reddit --network-alias=db_post --network-alias=db_comment mongo:latest
docker run -d --network=reddit --network-alias=post_new --env POST_DATABASE_HOST=db_post sjotus/post:1.0
docker run -d --network=reddit --network-alias=comment_new --env COMMENT_DATABASE_HOST=db_comment sjotus/comment:1.0
docker run -d --network=reddit -p 9292:9292 --env POST_SERVICE_HOST=post_new --env COMMENT_SERVICE_HOST=comment_new sjotus/ui:1.0
```

### Опитмизация докер-образов (*)

Сделаем оптимизацию образа ui, собрав его на alpine сохранив его в файле Dockerfile.1
Аналогичным образом переделаем и другие докерфайлы, попутно заменив инструкции ADD на COPY.

Создавая новые образы с помощью команды `docker build` будем повышать минорную версию в теге.

### Подключение вольюма к контейнеру

Создадим вольюм

```shell
docker volume create reddit_db
```

Теперь убьем старые контейнеры и запустим новые, при этом подключив к контейнеру с базой созданный вольюм. Таким образом, база будет сохраняться на вольюм и данные не пропадут со смертью контейнера

```shell
docker kill $(docker ps -q)
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db -v reddit_db:/data/db mongo:latest
docker run -d --network=reddit --network-alias=post ssjotus/post:1.0
docker run -d --network=reddit --network-alias=comment sjotus/comment:1.0
docker run -d --network=reddit -p 9292:9292 sjotus/ui:2.0
```

----
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
- Работа с DockerHub
- Прототип инфраструктуры (*)

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

### Работа с DockerHub

Стандартно докер скачивает образы с DockerHub. Мы можем зарегистрироваться и хранить там образы: [ссылка](https://hub.docker.com/)

Для того, что бы разместить образ, необходимо залогиниться в консоле:

```shell
docker login
```

Теперь поставим тег на наш образ и запушим его:

```shell
docker tag reddit:latest <your_login>/otus-reddit:1.0
docker push <your_login>/otus-reddit:1.0

```

После данный манипуляций мы можем использовать наш образ с докерхаба:

```shell
docker run --name reddit -d -p 9292:9292 sjotus/otus-reddit:1.0
```

### Прототип инфраструктуры (*)

Необходимо реализовать прототип инфраструктуры в диретории `docker-monolith/infra`:
- Поднятие инстансов терраформом
- Установка докера и запуск докер-образа приложения через ансибл
- Создание образа ВМ с установленным докером через пакер.

Решение:
В директории `docker-monolith/infra` создадим папки ansible, terraform, packer. Пакер должен на базе образа ubuntu-1604-lts создавать образ docker-base, в котором уже будет установлен докер. В качестве провиженера будем использовать ансибл. Терраформ должен будет развернуть виртуальную машинну (или несколько, в зависимости от переменной count) в GCP из образа, созданного пакером. Пока провиженеры использовать не будем. Ансибл должен уметь устанавливать докер, а так же запускать докер-контейнер с ранее созданного намии образа.

Структура директории ansible:
- В корне находятся файлы ansible.cfg, inventory.gcp.yml (динамическое инвентори для GCP) и Vagrantfile.
- директория playbooks будет содержать все плейбуки
- директория roles будет содержать роль docker, которая будет устанавливать докер

Сначала напишем роль по установке докера. Далее, для пакера сделаем плейбук `packer_docker.yml` который будет ипользовать роль. Для установки докера через ансибл сделаем плейбук `docker.yml`. Для установки различных зависимостей и питона сделаем плейбук `base.yml`. А для деплоя нашего контейнера - `deploy.yml`.

Плейбук `site.yml` будет основным. В него включим плейбуки base, docker и deploy.

Дополнительные действия:

Для ансибла необходимо создать дополнительный сервисный аккаунт в GCP в проекте docker. Ключ ищется в `~/ansible_gcp-docker_key.json`.

Для пакера необходимо создать variables.json с используемыми переменными.

Для терраформа необходимо создать terraform.tfvars.

Шаги для запуска:

```shell
cd docker-monollith/infra
# packer build
packer build -var-file=packer/variables.json packer/docker.json

# terraform
cd terraform && terraform apply

# ansible
cd ../ansible && ansible-playbook playbooks/site.yml

```
