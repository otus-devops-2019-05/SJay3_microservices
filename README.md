# SJay3_microservices
SJay3 microservices repository

[![Build Status](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/SJay3_microservices)

[Докер-хаб](https://hub.docker.com/u/sjotus)

## Homework 22 (kubernetes-4)
В данном домашнем задании было сделано:
- Работа с Helm
- Развертывание Gitlab в kubernetes

### Работа с helm
Helm - это пакетный менеджер для кубернетеса

#### Установка helm
Установим клиентскую часть helm. Будем устанавливать версию 2.13.1. Для этого перейдем по [ссылке](https://github.com/helm/helm/releases) и загрузим бинарник, соответствующей нашей ОС. Для установки на Linux (или WSL), необходимо скачать архив, распаковать его и разместить исполняемый файл `helm` в `/usr/local/bin` или `/usr/bin`.
Хельм читает `~/.kube/config` и сам определяет текущий контекст. Можно так же указать свой конфигу-файл указывая ключ `--kube-context`.

Теперь установим серверную часть helm - tiller. Tiller - это под, который общается с АПИ кубернетеса. Для работы, ему необходимо создать сервисный аккаунт и выдать роли RBAC.

В корне директории kubernetes создадим файл tiller.yml следующего содержания:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
```

Применим этот манифест:

```shell
kubectl apply -f tiller.yml
```


После чего запустим tiller-сервер командой:

```shell
helm init --service-account tiller
```

Проверим, что под запустился и работает:

```shell
kubectl get pods -n kube-system --selector app=helm
```

#### Charts
Chart - это пакет хельма.
Создадим собственные чарты для микросервисного приложения. Для этого, в директории kubernetes, создадим директорию Charts, в которой создадим папки comment, post, reddit, ui.

Начнем разработку чарта с компонента ui. В директории ui создадим файл Chart.yaml. Для хельма важны расширения файлов, поэтому он обязательно должен заканчиваться на `.yaml`

```yaml
name: ui
version: 1.0.0
description: OTUS reddit application UI
maintainers:
  - name: Someone
    email: my@mail.com
appVersion: 1.0
```


Поля `name` и `version` - самые значимые. От них зависит работа хельма. Остальные поля - это описание.
Создадим шаблоны манифестов для ui. Создадим папку templates и перенесем в нее все ранее созданные манифесты, что бы в дальнейшем их шаблонизировать.

У нас получился уже готовый, но пока не шаблонизированный пакет для хельма. Перед шаблонизацией, для проверки установим этот чарт:

```shell
helm install --name test-ui-1 ui/
```

Проверим, что произошло командой:

```shell
helm ls
```

Шаблонизируем файл templates/service.yaml так, что бы можно было использовать чарт для запуска нескольких экземпляров (релизов).

При шаблонизации можно использовать встроенные переменные:
- .Release - группа переменных с информацией о релизе
(конкретном запуске Chart’а в k8s)
- .Chart - группа переменных с информацией о Chart’е (содержимое
файла Chart.yaml)
Также еще есть группы переменных:
- .Template - информация о текущем шаблоне ( .Name и .BasePath)
- .Capabilities - информация о Kubernetes (версия, версии API)
- .Files.Get - получить содержимое файла

Шаблонизируем похожим образом все остальные файлы.

Для шаблонизации можно использовать не только встроенные переменне, но и определять свои. Определим следующие переменные:
- .Values.image.repository
- .Values.image.tag
- .Values.service.internalPort
- .Values.service.externalPort

Для того, что бы мы могли использовать эти переменные, определим их значения в файле ui/values.yaml

```yaml
service:
  internalPort: 9292
  externalPort: 9292
image:
  repository: sjotus/ui
  tag: latest
```

После шаблонизации обновим наш ui-сервис через helm:

```shell
helm upgrade test-ui-1 ui/
helm upgrade test-ui-2 ui/
helm upgrate test-ui-3 ui/
```

Шаблонизируем остальные сервисы post и comment

В хельме существует функционал хелперов. Helper - это написанная пользователем функция, в которой как правило реализована сложная логика. Эти функции располагаются в `templates/_helpers.tpl`.

Напишем свою функцию для чарта comment:

```
{{- define "comment.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name }}
{{- end -}}
```

Эта функция в результате выдаст тоже что и конструкция вида `{{ .Release.Name }}-{{ .Chart.Name }}`

Для использования хелперов, необхоимо указывать конструкцию вида `{{ template "comment.fullname" . }}`. Изменим шаблоны comment на использование нашего хелпера.

Конструкция вызова функций хелпера состоит из:
- ключевое слово template - это вызов функции template
- имя определенной в хелпере функции для импорта
- "." - это область видимости для импорта. "." - область видимости всех переменных.

Аналогичным образом создадим хелперы для 2-х других сервисов.

#### Управление зависимостями
На данном этапе у нас есть чарты для всех компонентов нашего приложения. Мы можем запускать их по отдельности, но они будут запускаться в разных релизах и не будут видеть друг друга. Для того, что бы этого не происходило, с помощью механизма управления зависимостями созадим единый чарт reddit, который будет объединять все наши компоненты.

В директории reddit создадим файл requirements.yaml

```yaml
---
dependencies:
  - name: ui
    version: "1.0.0"
    repository: "file://../ui"

  - name: post
    version: "1.0.0"
    repository: "file://../post"

  - name: comment
    version: "1.0.0"
    repository: "file://../comment"
```

Теперь загрузим все зависимости, т.к. наши чарты не упакованы в tgz-архив

```shell
cd Charts/reddit
helm dep update
```

Появится файл requirements.lock с фиксацией зависимостей. Будет создана директория charts с зависимостями в виде архивов.

Чарт для базы данных не будем создавать, а возьмем готовый.

```shell
# Найдем чарт в доступном репозитории
helm search mongo
```

Добавим в файл с зависимостями найденый нами чарт и обновим их

```yaml
...
  - name: mongodb
    version: 7.2.8
    repository: https://kubernetes-charts.storage.googleapis.com
```

Теперь установим наше приложение:

```shell
helm install reddit --name reddit-test
```

#### tiller plugin
В начале мы деплоили тиллер с правами cluster-admin. Это не безопасно. Есть концепция создавать тиллер в каждом неймспейсе, наделяя его соответствующими правами. Для того, что бы не делать этого каждый раз руками, будем использовать [tiller plugin](https://github.com/rimusz/helm-tiller). [Описание](https://rimusz.net/tillerless-helm).

1. Сначала удалим уже использующийся тиллер: https://stackoverflow.com/questions/47583821/how-to-delete-tiller-from-kubernetes-cluster/47583918
2. Выполним установку плагина и деплой в новый неймспейс reddit-ns

```shell
helm init --client-only
helm plugin install https://github.com/rimusz/helm-tiller
helm tiller run -- helm upgrade --install --wait --namespace=reddit-ns reddit reddit/
```

3. Проверим, что все получилось успешно, выполнив команду `kubectl get ingress -n reddit-ns` и пройдя по ip в ингрессе

#### Helm3

Установим Helm3, аналочино, как и устанавливали 2-ю версию.

Создадим новый неймспейс что бы протестировать новую версию хельма

```shell
kubectl create ns new-helm
```

Задеплоимся:

```shell
helm3 upgrade --install --namespace=new-helm --wait reddit-release reddit/
```

И проверяем:

```shell
kubectl get ingress -n new-helm
```


### Развертывание Gitlab в kubernetes


----
## Homework 21 (kubernetes-3)
В данном домашнем задании было сделано:
- Настройка сервиса типа LoadBalancer
- Использование объекта Ingress
- TLC Termination
- Описать объект secret в виде кубернетес-манифеста (*)
- Использование NetworkPolicy
- Хранилище для базы

### Настройка сервиса типа LoadBalancer
В прошлой дз мы установили у ui сервиса тип NodePort, который позволил нам по ip-адресу ноды и порту указанному в NodePort подключаться из вне к нашему сервису ui. Это не очень удобно. Поэтому с помощью типа сервиса LoadBalancer (этот тип доступен только в облачных провайдерах) мы настроим облачных балансировщик как единую точку входа для нашего сервиса ui.

Для этого в ui-service.yml изменим тип с NodePort на LoadBalancer + внесем еще несколько правок.

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ui
  labels:
    app: reddit
    component: ui
spec:
  type: LoadBalancer
  ports:
  - port: 80
    nodePort: 32092
    protocol: TCP
    targetPort: 9292
  selector:
    app: reddit
    component: ui
```

Проверим, что мы все указали правильно:

```shell
# apply changes
kubectl apply -f reddit/ui-service.yml -n dev

# get external-ip of service
kubectl get service -n dev --selector component=ui
```

Балансировка через service с типом LoadBalancer имеет следующие недостатки:

- нельзя управлять с помощью http URI (L7-балансировка)
- используются только облачные балансировщики (AWS,GCP)
- нет гибких правил работы с трафиком

### Использование объекта Ingress

Для более удобного управления и решения недостатков LoadBalancer можно использовать Ingress

Ingress - это набор правил внутри кластера кубернетес, предназначенных для того, что бы входящиие подключения могли достич объектов Service. Для применения правил Ingress необходим Ingress Controller.

Ingress Controller - это под, который состоит из 2-х функциональных частей:

- Приложение, которое отслеживает через API кубера новые объекты Ingress и обновляет конфигурацию балансировщика
- Балансировщик (nginx, haproxy, traefik ...), который управляет сетевым трафиком

В GKE есть возможность использовать их собственные решения балансировщика в качестве Ingress Controller.

Убедимся, что в настройках кластера в консоли GCP включен балансировщик (addons -> HTTP load balancing -> enabled).

Теперь создадим ингресс для сервиса ui. Файл назовем ui-ingress.yml

После применения конфигурации, в GCP Появится еще один балансировщик (на 7-м уровне). Посмотрим адрес ui-сервиса:

```shell
kubectl get ingress -n dev
```

Вернем обратно сервису ui тип NodePort, а в ингрессе пропишем правила балансировки:

```yaml
...
spec:
  rules:
  - http:
      paths:
      - path: /*
        backend:
          serviceName: ui
          servicePort: 9292
```

### TLC Termination

Настроим наш ингресс на прием только HTTPS трафика и терминацию его на границе кластетра (т.е. мы будем принимать только шифрованные соединения из вне по HTTPS, а внутри кластера по прежнему будет HTTP).

Создадим сертификат для с использованием ip как CN

```shell
# get ingress ip
kubectl get ingress -n dev
# generate cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=<Ingress_ip>"
```

Создадим объект типа secret для хранения сертификата в кластере

```shell
kubectl create secret tls ui-ingress --key tls.key --cert tls.crt -n dev
# view secret
kubectl describe secret ui-ingress -n dev
```

Теперь настроим ингресс на прием только https трафика.

```yaml
...
metadata:
  name: ui
  annotations:
    kubernetes.io/ingress.allow-http: "false"
spec:
  tls:
  - secretName: ui-ingress
...
```

Применим изменения и проверим в GCP что у нас используется только протокол HTTPS. Если это не так, то пересоздадим правила вручную:

```shell
kubectl delete ingress ui -n dev
kubectl apply -f reddit/ui-ingress.yml -n dev
```

### Описать объект secret в виде кубернетес-манифеста (*)
В предыдущей главе мы создали объект типа Secret через kubectl. Опишем его в виде манифеста кубернетес. Файл назовем ui-secret-ingress.yml.

Структура файла должна быть следующей:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: ui-ingress
type: kubernetes.io/tls
data:
  tls.crt: <base64_cert>
  tls.key: <base64_key>
```

Сертификат и ключ должны быть в base64:

```shell
cat tls.key | base64
cat tls.crt | base64
```

### Использование NetworkPolicy

Для того, что бы разнести сервисы базы данных и фронтенда по разным сетям мы будем использовать NetworkPolicy, т.к. в кубернетесе по умолчанию все поды могут достучаться друг до друга.

NetworkPolicy - это инструмент для декларативного описания потоков трафика. Не все сетевые плагины его поддерживают. В GKE мы включим сетевой плагин Calico, вместо Kubenet, для того, что бы использовать NetworkPolicy.

#### Включениек плагина Calico
Найдем имя кластера:

```shell
gcloud beta container clusters list
```

Включим network-policy:

```shell
gcloud beta container clusters update <cluster_name> \
  --zone=<zone_name> --update-addons=NetworkPolicy=ENABLED
gcloud beta container clusters update <cluster_name> \
  --zone=<zone_name> --enable-network-policy
```

#### Политика для монги

Создадим NetworkPolicy для бд монги. Файл mongo-network-policy.yml.

В разделе podSelector выбираем объекты к которым применяется политика.

В разделе policyTypes описываем запрещающие направления. Запретим все входящие подключения, но разрешим исходящие:

```yaml
...
policyTypes:
- Ingress
...
```

Далее идет раздел разрешающих правил. Разрешим все входящие подключения для сервисов post и comment.

```yaml
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: reddit
        matchExpressions:
        - key: component
          operator: In
          values:
          - comment
          - post
```

### Хранилище для базы

Сейчас для монги используется тип Volume emptyDir. При создании пода с таким типом, создается пустой докер вольюм, а при остановке пода - вольюм удалится навсегда. Вместо него, будем использовать gcePersistentDisk.

Создадим диск на Google Cloud:

```shell
gcloud compute disks create --size=25GB --zone=us-west1-c reddit-mongo-disk
```

Изменим mongo-deployment.yml удалив emptyDir и добавив gcePersistantDisk

```yaml
  volumes:
      - name: mongo-gce-pd-storage
        gcePersistentDisk:
          pdName: reddit-mongo-disk
          fsType: ext4
```

Для более удобного управления вольюмами мы можем использовать не отдельный диск для каждого пода, а отдельный ресурс хранилища, общий для всего кластера - PersistentVolume.

Создадим файл mongo-volume.yml с описанием PersistentVolume.

Так же создадим запрос на выдачу созданного нами ресурса - PersistentVolumeClaim (PVC). Файл mongo-claim.yml.

Подключим PVC к поду с монгой

```yaml
...
volumes:
      - name: mongo-gce-pd-storage
        persistentVolumeClaim:
          claimName: mongo-pvc
```

Для того, что бы создавать хранилища в автоматическом режиме и динамически выделять вольюмы, необходимо использовать StorageClass. Они описывают где и какие хранилища создаются.

Опишем StorageClass Fast что бы монтировались SSD диски для работы нашего хранилища. Файл storage-fast.yml.

Создадим новый клайм на запрос быстрых дисков - mongo-claim-dynamyc.yml.

Так же изменим в в деплойменте монги запрос с обычных дисков на ссд.

----
## Homework 20 (kubernetes-2)
В данном домашнем задании было сделано:
- Развернуть kubernetes в локальном окружении
- Запуск приложения в локальном кластере
- Использование неймспейсов в kubernetes
- Развернуть кубернетес в Google Cloud
- Развернуть GCE через terraform (*)

### Развернуть kubernetes в локальном окружении
#### Установка kubeclt
[Инструкция по установке](https://kubernetes.io/docs/tasks/tools/install-kubectl/).

Для установки на windows, необходимо скачать бинарник по [ссылке](https://storage.googleapis.com/kubernetes-release/release/v1.16.0/bin/windows/amd64/kubectl.exe), после чего прописать путь к бинарнику в PATH. Для этого отрыть свойсва компьютера -> Дополнительные параметры системы -> Переменные среды.
В секции "Системные переменные" найти Path и нажать изменить.

В случае, если был установлен Docker for Windows, то необходимо что бы путь к kubectl был указан раньше, чем путь к докеру, т.к. у докера есть свой kubectl.

#### Установка minikube
Для работы minikube нам понадобится установленный гипервизор. Для windows это может быть VirtualBox или Hyper-V.

[Инструкция по установке minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/)

Для установки на Windows, необходимо скачать инсталлер и установить миникуб.

#### Запуск minikube

Миникуб запускается командой:

```shell
minikube start
```

!! В Windows, консоль должна быть запущена от администратора. Так же, команды необходимо выполнять из корня диска C

По-умолчанию используется virtualbox, поэтому для запуска в hyper-v, необходимо запускать со специальным флагом:

```shell
minikube start --vm-driver=hyperv
```

Для выбора версии kubernetes можно использовать флаг `--kubernetes-version <version>`

Запустим кластер следующей командой:

```shell
minikube start --vm-driver=hyperv --kubernetes-version v1.15.3
```

#### Конфигурация kubectl

Конфигурация kubectl - это контекст.

Контекст состоит из:
- cluster - API сервера
- user - Пользователь для подключения к кластеру
- namespace - Область видимости (не обязательный параметр. По-умолчанию default)

Информация о контекстах сохраняется в файле `~/.kube/config` (В Windows: `<Домашняя папка пользователя>\.kube\config`)

Порядок конфигурирования kubectl:

1. Создать кластер:

```shell
kubectl config set-cluster ... cluster_name
```

2. Создать данные пользователя (credentials):

```shell
kubectl config set-credentials ... user_name
```

3. Создать контекст:

```shell
kubectl config set-context context_name \
--cluster=cluster_name \
--user=user_name
```

4. Использовать контекст:

```shell
kubectl config use-context context_name
```


Посмотреть текущий контекст:

```shell
kuectl config current-context
```

Список всех контекстов:

```shell
kubectl config get-contexts
```

### Запуск приложения в локальном кластере

Запустим 3 реплики сервиса ui (предварительно отредактировав файл ui-deployment.yml)

```shell
kubectl apply -f ui-deployment.yml
```

Проверим, что наш деплоймент запустился и существует 3 реплики сервиса ui:

```shell
kubectl get deployment
```

kubectl умеет пробрасывать порты на локальную машину

```shell
# найдем под используя селектор
kubectl get pods --selector component=ui
# Пробросим порт пода 9292 на локальный 8080
kubectl port-forward <podname> 8080:9292
```

Проброс порта работает только пока активна команда.

Опишем так же компоненты comment и post аналогичным образом, что и ui.

Сделаем описание деплоймента для монги. Но реплик у монги будет всего 1. Так же, примонтируем стандартный вольюм для хранения данных вне контейнера.

```yaml
    spec:
      containers:
      - image: mongo:3.2
        name: mongo
        volumeMounts:
        - name: mongo-persistent-storage
          mountPath: /data/db
      volumes:
      - name: mongo-persistent-storage
        emptyDir: {}
```

#### Использование сервисов
Для связи компонентов между собой и с внешним миром используется объект Service. Он определяет набор подов и способ доступа к ним.

Для того, что бы сервис ui мог связываться с post и comment, необходимо последним создать по объекту Service.

Создадим файлы comment-service.yml и post-service.yml.

Посмотреть объекты типа Service можно командой:

```shell
kubectl get services
```

Описание сервиса:

```shell
kubectl describe service <serviceName>
```

Т.к. сервисы post и comment используют монгу, то для монги создадим отдельный объект типа service. Опишем его в файле mongodb-service.yml

Поскольку у нас в докерфайлах для сервисов post и comment заданы переменные окружения с именами базы `post_db` и `comment_db` соответственно, но контейнеры с этими сервисами не смогут найти контейнер с именем mongodb. Для решения этой проблемы, создадим Service для БД comment (файл comment-mongodb-service.yml).

Так же изменим деплоймент для монги, добавив туда теги `comment-db:"true"`, а в деплойменте сервиса comment добавим переменную окружения с именем БД.

Аналогичным образом поступим с сервисом post, добавив для него лейблы в деплоймент монги, создав отдельный сервис и прописав переменную окружения в деплоймент post. Имя базы должно быть post-db

Для того, что бы обеспечить постоянный доступ снаружи к ui-сервису, необходимо создать объект типа Service с типом NodePort. Опишем создание этого сервиса в файле ui-service.yml.

Тип сервиса **NodePort** на каждой ноде кластера открывает порт из диапазона 30000-32767 и перенаправляет трафик на порт, который указан в targetPort. Можно самим указать порт, который необходимо открыть, но он тоже должен быть из этого диапазона.

#### Minikube
Minikube может отдавать web-страницы сервисов, которые были помечены типом NodePort:

```shell
minikube service ui
```

Посмотреть список сервисов:

```shell
minikube service list
```

В миникубе так же есть в комплекте несколько стандартных аддонов. Каждый аддон - это поды или сервисы, которые общаются с API кубернетиса.

Посомтреть список расширений:

```shell
minikube addons list
```

Один из интересных аддонов - это dashboard. Это ui для работы с kubernetes

### Использование неймспейсов в kubernetes
**Namespace** - это, по сути, виртуальный кластер внутри кластера кубернетиса. Неймспейсы можно использовать для создания различных окружений внутри кластера или же для какого-либо логического разделения работающих сервисов. Внутри неймспейса могут находиться свои объекты. Но не все объекты могут быть помещены в неймпейс. Существуют объекты, которые общие для всех неймспейсов.

В разных нейспейсах могут находиться объекты с одинковым именем.

По-умолчанию в кластере кубернетес уже существует 3 неймспейса:
- default - Для объектов для которых не определен другой неймспейс
- kube-system - для объектов созданных кубером и для управления им
- kube-public - для объектов к которым нужен доступ из любой точки кластера

#### Minikube dashboard
Если мы включим дашборд миникуба, то не увидим его поды в дефолтном неймспейсе. В ранних версиях minikube дашборд запускался в неймспейсе **kube-system**. В новых версиях дашборд находится в неймспейсе **kubernetes-dashboard**

Включим дашборд:

```shell
minikube addons enable dashboard
```

Посмотрим все объекты связанные с включенным дашбордом:

```shell
kubectl get all -n kubernetes-dashboard --selector k8s-app=kubernetes-dashboard
```

Можно активировать и сразу же запустить дашборд в браузере одной командой:

```shell
minikube dashboard
```

#### Создание среды для разработки
Отделим среду для разработки от всего остального кластера, создав dev namespace.

Опишем этот неймспейс в файле dev-namespace.yml

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

Запутим наше приложение в dev namespace

```shell
kubectl apply -f kubernetes/reddit/dev-namespace.yml
kubectl apply -n dev -f kubernetes/reddit/
```

Проверим результат:

```shell
minikube service ui -n dev
```

Добавим информациюю об окружении в контейнер, определим переменную окружения ENV.

### Развернуть кубернетес в Google Cloud
В GCP идем в Kubernetes Engin и нажимаем Create Cluster

После запуска кластера, нажмем на кнопку Connect и скопируем команду, для подключения к кластеру. В результате команды, у нас должен настроиться kubectl на доступ к нашему кластеру. Проверим:

```shell
kubectl config current-context
```

Запустим наше приложение в кубернетес-кластере GCP:

```shell
# Создадим dev namespace
kubectl apply -f reddit/dev-namespace.yml

# Развернем наше приложение
kubectl apply -f reddit -n dev
```

Создадим правило фаервола в GCP, с диапазоном портов 30000-32767.

Далее найдем внешний адрес любой из нод и порт публикации ui сервиса, после чего, откроем адрсе в браузере для проверки работоспособности приложения:

```shell
# node ip
kubectl get nodes -o wide

# ui port
kubectl describe service ui -n dev | grep NodePort
```

Зайдем в GCP и включим дашборд в кубернетесе. После загрузки кластера, выполним в консоли команду:

```shell
kubectl proxy
```

И в браузере введем:
`http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/#!/login` для доступа к дашборду.

Для входа в дашборд понадобится токен в новых версиях кубернетиса. Что бы можно было пропустить шаг со вставкой токена и загрузить дашборд выполним:

```shell
kubectl edit deployment/kubernetes-dashboard --namespace=kube-system
```

Откроется редактор. Найдем секцию containers и добавим в args аргумент `--enable-skip-login`

```yaml
    containers:
      - args:
        - --auto-generate-certificates
        - --enable-skip-login  
```

Для того, что бы дашборд не застрял на авторизации, необходимо сервис-аккаунту дашборда назначить роль cluster-admin:

```shell
kubectl create clusterrolebinding kubernetes-dashboard  --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

P.S. У меня так и не заработал дашборд. При изменении деплоймента и добавлении `--enable-skip-login` сначала все вроде применяется, но после того, как в браузере открываешь страницу, все равно запрашивается аутентификация. А исправленное значение в деплойменте бесследно исчезает...как будто его там и не было.

### Развернуть GCE через terraform (*)

Создадим директорию kubernetes/terraform_gke в которую поместим файлы конфигурации терраформа, для развертывания кластера kubernetes в GCP (используя Google Kubernetes Engine).

Для полноценной работы, обязательно использовать версию провайдер > 2.3.0
При развертывании кубернетис кластера через террформ с использованием GKE, сначала будет развернут кластер с дефолтными нодами, т.к. нельзя развернуть кластер без нод. После этого, дефолтный node-pool будет удален и вместо него создастся описаный в `google_container_node_pool` пул нод.
Важно, что если в свойстве location кластера указать зону, то будет развернута только 1 мастер в указанной зоне. Если указать регион, то будет развернуто по экземпляру мастера в каждой зоне региона. Аналогичная ситуация со свойством location в пуле нод. Если указать зону, то в зоне будет развернуто указанной в `node_count` колличество нод. Но если указать регион, то в каждой зоне указанного региона будет развернуто колличество нод, указанное в `node_count`

----
## Homework 19 (kubernetes-1)
В данном домашнем задании было сделано:
- Пройти The Hard Way
- Описать установку компонентов kubernetes через плейбуки ansible (*)

### Пройти The Hard Way
The Hard Way - это туториал по установке kubernetes, разработанный инженером Google Kelsey Hightower.
Туториал представляет собой:
- Пошаговое руководство по ручной установке основных компонентов kubrnetes кластера
- Краткое описание необходимых действий и объектов.

Но перед тем, как проходить "Сложный путь", подготовим наш репозиторий.

В корне репозитория создадим папку kubernetes, внутри которой создадим папку reddit. Внутри создадим файлы для деплоймента наших микросервисов в кластер кубернетиса: commetn-deployment.yml, mongo-deployment.yml, post-deployment.yml и ui-deployment.yml

#### The Hard Way. Начало
Оригинальный [The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

В оригинальном The Hard Way используется kubernetes версии 1.12 + изменились ограничения в GCP на количество IP адресов. Поэтому, будем проходить The Hard Way [адаптированный Отусом](https://github.com/express42/kubernetes-the-hard-way), который расчитан на версию 1.15.

upd (20.09.19): Произошло обновление репозитория с оригинальным The Hard Way, поэтому его тоже можно использовать.

Создадим директорию `the_hard_way` внутри директории kubernetes. Туда мы будем складывать все файлы, созданные в ходе прохождения "Сложного пути".

### Описать установку компонентов kubernetes через плейбуки ansible (*)

Для автоматизации "Сложного Пути" будем использовать terraform + ansible.

Терраформ будет осуществлять развертывание инфраструктуры в gcp.

Ансибл автоматизирует генерацию сертификатов и ключей, файлов конфигураций, установку необходимого ПО, а так же конфигурирование локального kubectl для управления кластером.

Последовательность действий:

1. Выполняем первые 2 шага из руководства (подготавливаем свое окружение) и шаг 6 (Полученный файл сохранить в kubernetes/ansible/files/).
2. Идем в папку kubernetes/terraform. Создаем файл с параметрами terraform.tfvars и запускаем `terraform apply`. У нас создастся инфраструктура вместе с лоад балансером.
3. Идем в папку kubernetes/ansible. Предварительно для ансибла необходимо создать сервисный аккаунт в GCP, сохранить себе ключ и указать путь в файле inventory.gcp.yml. Запускаем плейбук `ansible-playbook playbooks/kubernetes.yml`
4. Выполняем оставшиеся пункты руководства, начиная с 11.

----
## Homework 18 (logging-1)
В данном домашнем задании было сделано:
- Подготовка окружения
- Elastic Stack
- Структурированные логи
- Неструктурированные логи
- Разбор логов с помощью grok-шаблонов (*)
- Распределенный трейсинг (*)

### Подготовка окружения
1. Скачаем новую версию приложения reddit и обновим его в папке /src ([ссылка](https://github.com/express42/reddit/tree/logging))
2. Создадим новую машину через docker-machine:

```shell
export GOOGLE_PROJECT=docker-248611
$ docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-open-port 5601/tcp \
    --google-open-port 9292/tcp \
    --google-open-port 9411/tcp \
    logging

# configure local env
$ eval $(docker-machine env logging)

# узнаем IP адрес
$ docker-machine ip logging
```

3. Соберем новые образы приложений. Можно сделать это через makefile:

```shell
export USER_NAME=sjotus
make reddit-micro
```

### Elastic Stack

Поднимим центральную систему логирования на эластике. Однако, вместо стандартного для ELK logstash будем использовать fluentd (т.е. реализуем EFK стек)

Создадим отдельный докер-композ файл для системы логирования. Назовем файл `docker-compose-logging.yml`

Не забудем открыть в GCP порты 24224 (tcp & udp), 9200 и 5601 для наших сервисов.

Создадиим в репозитории директорию logging, где будем хранить все, что связано с логированием.

#### Fluentd
В диретории logging создадим папку fluentd, где создадим простой докер-файл для нашего образа fluentd.

Cоздадим конфигурационный файл fluent.conf в диретории fluentd.

Внесем так же информацию о сборке fluentd-образа в makefile и соберем образ:

```shell
make fluentd
```

#### elasticsearch

При запуске эластика может возникнуть ошибка и контейнер с ним умрет:

```
max virtual memory areas vm.max_map_count [65530] is too low, increase to at least [262144]
```

Для исправления, необходимо поправить параметры ядра linux на хосте с докер-контейнерами:

```shell
docker-machine ssh logging
sudo vim /etc/sysctl.conf
```

Необходимо добавить параметр:

```
vm.max_map_count = 262144
```

И применить параметры ядра:

```shell
sudo sysctl -p
```

### Структурированные логи
#### Предварительная подготовка
Поменяем в `.env` файле теги образов наших микромервисов:

```
UI_VERSION=logging
POST_VERSION=logging
COMMENT_VERSION=logging
```

Запустим наши приложения и подключимся к сервису post для просмотра логов:

```shell
cd docker
docker-compose -f docker-compose.yml up -d
docker-compose logs -f post
```

#### Отправка логов в Fluentd
Для отправки логов в fluentd будем использовать докер-драйвер [fluentd](https://docs.docker.com/config/containers/logging/fluentd/). Добавим его в докер-композ файл.

```yaml
  post:
    ...
    logging:
      driver: "fluentd"
      options:
        fluentd-address: localhost:24224
        tag: service.post
```

Пересоздадим инфраструктуру и поднимем инфру для логирования.

#### Использование фильтров в fluentd
Для парсинга JSON в логе, определим фильтры в конфигурации fluentd. Файл `logging/fluentd/fluent.conf`

```
<filter service.post>
  @type parser
  format json
  key_name log
</filter>
```

Пересоберем образ и перезапустим сервис.

### Неструктурированные логи
Неструктурированные логи - это логи, формат которых не подстроен под систему централизованного логирования. Они не имеют четкой структуры

#### Логирование UI сервиса
Добавим драйвер fluentd к сервису UI по аналогии с сервисом post.

Перезапустим сервис и посмотрим в kibana на неструктурированные логи.

Для того, что бы распарсить такой лог, необходимо использовать регулярки. Добавми фильтр с регуляркой в fluent.conf

```
<filter service.ui>
  @type parser
  format /\[(?<time>[^\]]*)\]  (?<level>\S+) (?<user>\S+)[\W]*service=(?<service>\S+)[\W]*event=(?<event>\S+)[\W]*(?:path=(?<path>\S+)[\W]*)?request_id=(?<request_id>\S+)[\W]*(?:remote_addr=(?<remote_addr>\S+)[\W]*)?(?:method= (?<method>\S+)[\W]*)?(?:response_status=(?<response_status>\S+)[\W]*)?(?:message='(?<message>[^\']*)[\W]*)?/
  key_name log
</filter>
```

Пересоберем образ и перезапустим контейнер

#### Использование grok-шаблонов
Для того, что бы не писать регулярные выражения самому, можно использовать grok-шаблоны. По сути это именнованные шаблоны регулярных выражений.

Заменим нашу регулярку на grok-шаблон:

```
<filter service.ui>
  @type parser
  key_name log
  format grok
  grok_pattern %{RUBY_LOGGER}
</filter>
```

Это grok-шаблон, зашитый в плагин для fluentd. В развернутом виде он выглядит вот так:

```
%{RUBY_LOGGER} [(?<timestamp>(?>\d\d){1,2}-(?:0?[1-9]|1[0-2])-(?:(?:0[1-9])|(?:[12][0-9])|(?:3[01])|[1-9])[T ](?:2[0123]|[01]?[0-9]):?(?:[0-5][0-9])(?::?(?:(?:[0-5]?[0-9]|60)(?:[:.,][0-9]+)?))?(?:Z|[+-](?:2[0123]|[01]?[0-9])(?::?(?:[0-5][0-
9])))?) #(?<pid>\b(?:[1-9][0-9]*)\b)\] *(?<loglevel>(?:DEBUG|FATAL|ERROR|WARN|INFO)) -- +(?<progname>.*?): (?<message>.*)
```

Для полноценного парсинва будем использовать несколько grok-шаблонов. Поэтому добавим еще секцию с фильтром в конфиг fluentd

```
<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| request_id=%{GREEDYDATA:request_id} \| message='%{GREEDYDATA:message}'
  key_name message
  reserve_data true
</filter>
```

### Разбор логов с помощью grok-шаблонов (*)
Часть логов сервиса ui осталось неразобранной. Необходимо разобрать их через grok-шаблоны.

Добавим новый фильтр после предыдущего:

```
<filter service.ui>
  @type parser
  format grok
  grok_pattern service=%{WORD:service} \| event=%{WORD:event} \| path=%{URIPATH:path} \| request_id=%{GREEDYDATA:request_id} \| remote_addr=%{IPORHOST:remote_addr} \| method=%{GREEDYDATA:method} \| response_status=%{NUMBER:response_status}
  key_name message
  reserve_data false
</filter>
```

### Распределенный трейсинг (*)
Добавим в докер-композ файл для логирования сервис zipkin, который нужен для сбора информации о распределенном трейсинге

```yaml
services:
  ...
    zipkin:
    image: openzipkin/zipkin
    ports:
      - "9411:9411"
```

Не забудем отрыть порт в GCP

Так же, для каждого сервиса добавим переменную `ZIPKIN_ENABLED`, а в `.env` файле укажем:

```
ZIPKIN_ENABLED=true
```

Что бы зипкин получал трассировку, он должен быть в одной сети с микросервисами. Поэтому объявим сети нашего приложения в `docker-compose-logging.yml`, а так же добавим в эти сети zipkin.

Пересоздадим нашу инфраструктуру.

#### Сломанное приложение
Задание заключается в следующем:

```
С нашим приложением происходит что-то странное.
Пользователи жалуются, что при нажатии на пост они вынуждены долго ждать, пока у них загрузится страница с постом. Жалоб на загрузку других страниц не поступало. Нужно выяснить, в чем проблема, используя Zipkin.
```

[сломанное приложение](https://github.com/Artemmkin/bugged-code).

Для начала подготовим инфраструктуру. Что бы не ломать уже существующее приложение, скачаем сломанное в отдельную папку и соберем сервисы с тегом bug

```shell
git clone https://github.com/Artemmkin/bugged-code reddit_bug && rm -rf ./reddit_bug/.git
```

Отредактируем файлы docker_build.sh внутри каждого из микросервисов, добавив тег bug, после чего выполним скрипты, что бы собрались образы.

```shell
export USER_NAME=sjotus
for i in ui post-py comment; do cd reddit_bug/$i; bash docker_build.sh; cd -; done

```

Т.к. в докерфайлах приложения не указаны переменные окружения, то укажем их в докер-композ файле.

Для ui:

```
- POST_SERVICE_HOST=post
- POST_SERVICE_PORT=5000
- COMMENT_SERVICE_HOST=comment
- COMMENT_SERVICE_PORT=9292
```

Для post:

```
- POST_DATABASE_HOST=post_db
- POST_DATABASE=posts
```

Для comment:

```
- COMMENT_DATABASE_HOST=comment_db
- COMMENT_DATABASE=comments
```

Далее отредактируем .env файл, проставив тег bug у приложений и запустим инфраструктуру:

```shell
docker-compose -f docker-compose.yml -f docker-compose-logging.yml up -d
```

Попытаемся загрузить страницу с постом и заметим, что она долго загружается. Переключимся в зипкин и посмотрим трейсы. Можем увидеть трейс, который выполнялся 3с. Если мы взгянем на него подробнее, то увидим, что основное время запроса занял поиск поста в БД, значит проблема в запросах к БД.

Заглянем в исходный код сервиса post в файл `post_app.py` и найдем функцию отвечающую за поиск одного поста. Увидим, что в условии, если пост найден стоит задержка (`time.sleep(3)`).

Закомментируем этот кусок кода, пересоберем приложение для проверки и увидим, что запросы теперь выполняются намного быстрее.

----
## Homework 17 (monitoring-2)
В данном домашнем задании было сделано:
- Мониторинг докер-контейнеров
- Визуализация метрик через Grafana
- Мониторинг работы приложений
- Алертинг
- Задания со *
- Задания с **
- Задания с ***

### Мониторинг докер-контейнеров
Структурируем докер-композ файл. Оставим в стандартном файле только запуск приложений, а все, что касается мониторинга вынесем в файле `docker-compose-monitoring.yml`.

Добавим в docker-compose-monitoring.yml экспортер для наблюдения за состоянием наших контейнеров [cAdvisor](https://github.com/google/cadvisor). Так же добавим информацию о сервисе в prometheus.yml, после чего пересоберем контейнер с прометеусом.

```yaml
- job_name: 'cadvisor'
  static_configs:
    - targets:
      - 'cadvisor:8080'
```

Не забудем так же добавить правило фаервола в GCP для порта 8080

### Виизуализация метрик через Grafana
Для визуализации метрик будем использовать Grafana.

Добави графану как сервис в docker-compose-monitoring.yml. Не забудем добавить правило фаервола в GCP на открытие порта 3000 что бы можно было зайти в графану.

Откроем графану по адресу http:\\<docker-host_ip>:3000. В качестве логина и пароля выступают значения переменных окружения, которые мы задали в докер-композ файле: `GF_SECURITY_ADMIN_USER` и `GF_SECURITY_ADMIN_PASSWORD`

#### Подключение графаны к прометеусу
Подключение к прометеусу идет из коробки.
Нажмем на **Add data source**, в поле **Name** введем *Prometheus Server*, выберем **Type** *Prometheus*. В поле **URL** введем `http://prometheus:9090`. После чего нажмем кнопку **Save&Test**.

#### Дашборы в графане
У графаны есть громное колличество дашбордов, которые можно найти и скачать на [официальном сайте](https://grafana.com/grafana/dashboards).

Найдем популярный дашборд для дата сорса прометеус и категории docker. Пример: Docker and system monitoring.

Выберем найденный дашборд и нажмем на кнопку **Download JSON**. Скачаем данный JSON в директорию `monitoring/grafana/dashboards`. Переименуем его в DockerMonitoring.json

Далее в веб-интерфейсе графаны наведем мышкой на знак "+" и выберем пункт **Import**. Нажмем на кнопку **Import JSON** и выберем наш скачанный json-файл дашборда. Далее выберем созданный нами ранее датасорс и нажмем на кнопку **Import**. После всех манипуляций на экране появится дашборд.


### Мониторинг работы приложений
Добавим в конфиг прометеуса информацию о сервисе post. После чего пересоберем образ прометеуса.

Добавим в графане 3 дашборда:
- DockerMonitoring
- UI_Service_Monitoring
- Business_Logic_Monitoring

### Алертинг
Для организации алертинга будем использовать дополнительный компонент для прометеуса *Alertmanager*

Создадим директорию `monitoring/alertmanager` в которой создадим Dockerfile:

```dockerfile
FROM prom/alertmanager:v0.14.0
ADD config.yml /etc/alertmanager/
```

Создадим в директории alertmanager файл config.yml в котором опишем конфигурацию aleermanager.

В секции global определим параметр `slack_api_url` в котором определим url к апи слака выданого плагином Incoming Webhook.

Соберем образ алертменеджера. Для удобства, можно добавить сборку и пуш в Makefile.

Добавим в докер-композ файл наш новый сервис:

```yaml
  alertmanager:
    image: ${USER_NAME}/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
    ports:
      - 9093:9093
    networks:
      - prometheus
```

Не забудем так же открыть порт 9093 в GCP для доступа к веб-интерфейсу алертменеджера.

Условия, при которых будет срабатывать алертинг, поместим в файл `monitoring/prometheus/alerts.yml`

```yaml
groups:
  - name: alert.rules
    rules:
    - alert: InstanceDown
      expr: up == 0
      for: 1m
      labels:
        severity: page
      annotations:
        description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute'
        summary: 'Instance {{ $labels.instance }} down'
```

Теперь обновим докер-файл прометеуса добавив в него копирование файла alerts

```Dockerfile
...
ADD alerts.yml /etc/prometheus/
```

Так же в конфиг прометеуса добавим информацию о правилах и местонахождение алертменеджера:

```yaml
rule_files:
  - "alerts.yml"

alerting:
  alertmanagers:
  - scheme: http
    static_configs:
    - targets:
      - "alertmanager:9093"
```

Теперь остается только пересобрать образ прометеуса и пересоздать инфраструктуру:

```shell
export USER_NAME=sjotus
make prometheus-all
cd docker
docker-compose -f docker-compose-monitoring.yml down
docker-compose -f docker-compose-monitoring.yml up -d
```

Проверим, что правило отображается в прометеусе на вкладке Alerts.

Проверим работу алертинга остановив один из сервисов. В канал в слаке должно будет прийти уведомление.

### Задания со *
#### Добавление в Makefile сборки и пуша образов из данного ДЗ

см. раздел Алертинг

#### Сбор метрик прометеусом с докера
В докере в экспериментальном режиме реализована отдача метрик в прометеус ([ссылка](https://docs.docker.com/config/thirdparty/prometheus/))

Для начала необходимо включить метрики в докере.

```shell
docker-machine ssh
sudo vim /etc/docker/daemon.json
```

В файле daemon.json (конфигурация только для тестирования. В Продакшене в GCP не стоит её использовать)

```json
{
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
```

И перезапусим докер.

```shell
sudo systemctl restart docker.service
```

Не забудем в фаерволе GCP отрыть порт 9323.

Далее в конфиге prometheus.yml добавим:

```yaml
...
  - job_name: 'docker'
    static_configs:
      - targets: ['<docker-host_ip>:9323']
```

Пересоберем прометеус и запустим инфраструктуру:

```shell
make prometheus
cd docker && docker-compose -f docker-compose-monitoring.yml up -d
```

По сравнению с cAdvisor стандартные докеровские метрики скудны. Но они дают информацию о работе докер-энжина.

Дашборд для метрик: `Docker_Engine_metrics.json`

#### Сбор метрик с докера с использованием Telegraf

Создадим в папке monitoring/exporters директорию telegraf. Создадим в ней конфигурационный файл для телеграфа telegraf.conf. В файле опишем конфигурацию импута (докер) и оутпута (прометеус).

Там же создадим докерфайл для создания образа с телеграфом, где опишем добавление файла конфигурации внутрь контейнера.
Не забудем поправить makefile, что бы можно было собирать и пушить наш образ.

Теперь соберем наш образ.

Далее добавим сервис телеграф в докер-композ файл.

```yaml
  telegraf:
    image: ${USERNAME}/telegraf
    networks:
      - prometheus
    volumes:
      - '/var/run/docker.sock:/var/run/docker.sock'
```

Так же, добавим сервис в конфиг прометеуса:

```yaml
  - job_name: 'telegraf'
    static_configs:
      - targets:
        - 'telegraf:9273'
```

Пересоберем образ прометеуса и переподнимем нашу инфраструктуру.

#### Реализовать другие алерты
Реализуем алерт на 95 процентил времени ответа UI с расслыкой умедомления на email помимо слака.
Для тестирования будем алертить в случае, если значение больше 0,1. 

Добавим в файле alert.yml новый алертинг, после чего пересоберем образ с прометеусом.

Для тестирования email-уведомлений будем использовать тестовый сервис [mailtrap](https://mailtrap.io/). После регистрации в сервисе, необходимо зайти в Inbox -> Demo inbox. Там будет доступна конфигурация почтового сервера (адрес, логин и пароль). Будем их использовать для конфигурации алертменеджера.

Отредактируем конфиг алертменеджера (config.yml) добавив туда отправку на наш тестовый почтовый ящик.

### Задания с **
#### Автоматическое добавление датасорсов и дашбордов в графану

Согласно [документации](https://grafana.com/docs/administration/provisioning/) в директории `/etc/grafana` необходимо создать диреторию `provisioning` а внутри каталоги datasources и dashboards для датасорсов и дашбордов соответсвенно. 

Путь к директории можно изменить в конфигурационном файле. [Документация](https://grafana.com/docs/installation/configuration/#provisioning)

Для начала опишем конфигурацию датасорсов и дашбордов в виде файлов. В диретории monitoring/grafana/ Создадим директорию provisioning, а внутри директории dashboards и datasources.

Файл `dashboards.yml` и `datasources.yml` будут содержать нашу конфигурацию. Поместим их в соответствующие директории.

Теперь создадим докер-файл для графаны, в котором опишем добавление созданной нами конфигурации.

Не забудем добавить сборку и пуш графаны в makefile.

#### Сбор метрик со stackdriver
Stackdriver - это сервис по сбору метрик, логов и трейсов, а так же алертинг.

Для сбора метрик и логов необходимо предварительно установить агентов. [quickstart](https://cloud.google.com/monitoring/quickstart-lamp)

Установим агента мониторинга:

```shell
docker-mashine ssh docker-host
curl -sSO https://dl.google.com/cloudagents/install-monitoring-agent.sh
sudo bash install-monitoring-agent.sh
```

После этого в stackdriver будут приходить метрики. Их можно посмотреть на вкладке resources -> Metrics Explorer

Базовые метрики по конкретному хосту можно увидеть зайдя в resources -> instances и выбрав конкретный инстанс.

Можно организовать так же blackbox метрики. В стакдрайвер это называется Uptime Checks
Необходимо зайти в панель мониторинга stackdriver и выбрать uptime checks -> uptime checks overwiev. В правом углу нажать на кнопку Add Uptime Check. Далее заполняем поля. Для проверки что чек работает, можно нажать на Test.


Теперь, когда у нас есть метрики в стакдрайвере, мы можем их выгружать в прометеус.
Будем использовать этот [экспортер](https://github.com/frodenas/stackdriver_exporter).

Предварительно создадим сервисный аккаунт stckdriver и назначим ему роль monitoring Viewer.

Сгенерируем ключ и сохраним его под именем gcp-stackdriver-docker-key.json на машину docker-host в предварительно созданный каталог `/var/gcp-cred/`

Добавим конфигурацию стакдрайвер-экспортера в докер-композ файл:

```yaml
  stackdriver-exporter:
    image: frodenas/stackdriver-exporter
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/var/gcp-cred/gcp-stackdriver-docker-key.json
      - STACKDRIVER_EXPORTER_GOOGLE_PROJECT_ID=docker-248611
      - STACKDRIVER_EXPORTER_MONITORING_METRICS_TYPE_PREFIXES=compute.googleapis.com/instance/cpu,compute.googleapis.com/instance/disk
    ports:
      - 9255:9255
    networks:
      - prometheus
    volumes:
      - /var/gcp-cred:/var/gcp-cred
```

В данной конфигурации он будет собирать все метрики о ЦПУ и Дисках со всех инстансов.

Добавим экспортер в конфигурацию прометеуса:

```yaml
  - job_name: 'stackdriver'
    static_configs:
      - targets:
        - 'stackdriver-exporter:9255'
```

Остается пересобрать образ прометеуса и задеплоить инфраструктуру

### Задания с ***
#### Реализовать схему проксирования между графаной и прометеусом через Trickster

Trickster - это кэширующий прокси от компании Comcast. Он специально создан для проксирования запросов к прометеусу, для ускорения отрисовки дашбордов в графане. [Github](https://github.com/Comcast/trickster).

В директории monitoring/trickster создадим конфигурационный файл сервиса trickster.conf. Там же создадим докер файл для сборки сервиса.

Не забудем добавить в makefile сборку и пуш образа.

Добавим сервис в докер-композ файл.

```yaml
  trickster:
    image: ${USERNAME}/trickster
    ports:
      - 9089:9089
    depends_on:
      - prometheus
    networks:
      - prometheus
```

Изменим так же конфигурацию датасорсов в графане, на юрл трикстера


----
## Homework 16 (monitoring-1)
В данном домашнем задании было сделано:
- Запуск prometheus в контейнере
- Упорядочивание репозитория
- Сборка собственного образа prometheus
- Оркестрация через docker-compose и сбор метрик
- Использование exporters
- Мониторинг MongoDb (*)
- Мониторинг сервисов с помощью Blackbox exporter (*)
- Использование make для сборки образов (*)

### Запуск prometheus в контейнере

Перед запуском прометеуса подготовим окружение.
Необходимо добавить правила фаервола в GCP и создать ВМ с докером через docker-machine (если она еще не была создана).

Правила фаервола:

```shell
gcloud compute firewall-rules create prometheus-default --allow tcp:9090
gcloud compute firewall-rules create puma-default --allow tcp:9292
```

Создание ВМ

```shell
export GOOGLE_PROJECT=docker-248611

# create docker host
docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host
```

Подключаемся к удаленному хосту через докер-машин

```shell
eval $(docker-machine env docker-host)
```

Запустим прометеус в контейнере. Будем использовать уже готовый образ с докер-хаба

```shell
docker run --rm -p 9090:9090 -d --name prometheus  prom/prometheus
```

Ознакомимся с основными элементами web-интерфейса прометеуса и остановим контейнер командой:

```shell
docker stop prometheus
```

### Упорядочивание репозитория

Приведем структуру каталогов в более удобный и четки вид. Для этого, создадим папку **docker** в корне репозитория и перенесем туда директорию **docker-monolith**, а так же все docker-compose и `.env` файлы из директории **src**. Так же удалим все инструкции *build* из файле `docker-compose.yml`

В корне репозитория создадим папку **monitoring**, в которой будем хранить все, что связано с мониторингом.

### Сборка собственного образа prometheus

Создадим внутри директории **monitoring** диреткорию **prometheus**, внутри которой создадим **Dockerfile**

```Dockerfile
FROM prom/prometheus:v2.1.0
ADD prometheus.yml /etc/prometheus/
```

И далее рядом создадим файл конфигурации `prometheus.yml`

Теперь все готово для сборки образа

```shell
export USER_NAME=<docker_hub_login>
docker build -t $USER_NAME/prometheus .
```

### Оркестрация через docker-compose и сбор метрик
У нас уже есть докер-композ файл для поднятия наших сервисов, поэтому нам необходимо подключить туда поднятие прометеуса.

Но для начала пересоберем все образы наших сервисов через скрипт `docker_build.sh`, который находится в директории каждого сервиса в каталоге src.

Скрипт для сборки всего из корня репозтория

```shell
for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done
```

Теперь добавим в файл `docker/docker-compose.yml` информацию о сервисе с прометеусом.

Проверим, что для сервиса базы данных установленны все алиасы (необходимо, что бы другие сервисы могли обращаться к сервису базы данных)

Теперь мы можем подключиться к прометеусу и посмотреть метрики. Зайдем по адресу `http://<docker-host-ip>:9090` посмотрим на метрики `ui_healht`, `ui_health_comment_availability` и `ui_health_post_availability` и убедимся что прометеус собирает метрики с наших сервисов.

### Использование exporters
Экспортер похож на вспомогательного агента для сбора метрик.
В ситуациях, когда мы не можем реализовать отдачу метрик Prometheus в коде приложения, мы можем использовать экспортер, который будет транслировать метрики приложения или системы в формате доступном для чтения Prometheus.

Настроим сбор метрик с докер-хоста. Для этого воспользуемся экспортером [Node exporter](https://github.com/prometheus/node_exporter). Экспортер будем так же запускать в контейнере, поэтому добавим его как сервис в docker-compose файл. Так же создадим дополнительную сеть prometheus_net, к которой подключим прометеус и наш экспортер.

В конфиг прометеуса (prometheus.yml) добавим еще одну джобу, что бы прометеус следил за экспортером

```yaml
scrape_configs:
...
  - job_name: 'node'
    static_configs:
      - targets:
        - 'node-exporter:9100'
```

И пересоберем контейнер с прометеусом:

```shell
export USER_NAME=sjotus
cd monitoring/prometheus && docker build -t $USER_NAME/prometheus .
```

### Мониторинг MongoDb (*)

В качестве экспортера для монги будем использовать [экспортер от перконы](https://github.com/percona/mongodb_exporter).

Сделаем следующее:

```shell
mkdir -p monitoring/exporters
cd monitoring/exporters
```

Добавим в .gitignore будущий репозиторий с экспортером для монги:

```
# exclude mongodb-exporter repo
monitoring/exporters/mongodb-exporter/.*
monitoring/exporters/mongodb-exporter/
```

Напишем скрипт `mongodb_exporter.sh`, который будет клонировать репозиторий с экспортером монги, собирать докер-образ экспортера и пушить его в наш докер-хаб.

Теперь залогинимся в докер хаб и запустим шелл скрипт.

```shell
docker login
./mongodb_exporter.sh
```

Добавим новый таргет в конфигурацию прометеуса (`monitoring/prometheus/prometheus.yml`) и пересоберем образ.

```yaml
  - job_name: 'mongo'
    static_configs:
      - targets:
        - 'mongodb-exporter:9216'
```

Добавим в наш докер-композ файл (`docker/docker-compose.yml`) сервис mongodb-exporter:

```yaml
  mongodb-exporter:
    image: sjotus/mongodb-exporter
    command:
      - '--mongodb.uri=mongodb://post_db'
      - '--collect.database'
    networks:
      prometheus:
        aliases:
          - mongodb-exporter
      reddit_back:
```

Остается только запустить и проверить, что таргет в состоянии UP и метрики собираются

```shell
cd docker && docker-compose -f docker-compose.yml up -d
```

### Мониторинг сервисов с помощью Blackbox exporter (*)

[Blackbox exporter](https://github.com/prometheus/blackbox_exporter)

Добавим сервис blackbox-exporter в докер-композ файл:

```yaml
  blackbox-exporter:
    image: prom/blackbox-exporter:v0.14.0
    ports:
      - '9115:9115'
    # volumes:
    #   - '../monitoring/exporters/blackbox-exporter:/config'
    # command:
    #   - '--config.file=/config/blackbox.yml'
    networks:
      - prometheus
      - reddit_front
      - reddit_back
```

А данном задании мы будем использовать только один модуль в экспортере для проверки статус-кодов http 2xx. Для продакшн-реди решения необходимо подключать вольюм и указывать заранее подготовленный конфиг-файл в данном вольюме (закомментированные строки в файле docker-compose.yml).

В разделе networks укажем все сети из которых должен быть видет экспортер для сборка метрик и взаимодействия с прометеусом.

**P.S.** Не смог разобраться, почему экспортер в итоге не видит сервисов post и comment. Возможно проблема с портами или алиасами...

Теперь добавим в prometheus.yml конфигурацию blackbox-exporter. Данный экпортер работает по указанным в конфиге таргетам, поэтому для сбора метрик с разных сервисов одним экспортеторм, необходимо заменить стандартные лейблы.

```yaml
  - job_name: 'blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - 'ui:9292'
        - 'comment:9292'
        - 'post:5000'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

### Использование make для сборки образов (*)

Для сборки образов через команду make, необходимо создать Makefile в корне репозитория. Этот файл должен удовлетворять условиям:

- сборка микросервисов из папки src
- сборка прометеуса monitoring/prometheus
- сборка экспортера для монги
- Пуш в докер-хаб образа прометеуса
- Пуш в докер-хаб образов микросервисов из папки src

Перед выполнением команды make, необходимо определить переменную `USER_NAME`, которая отвечает за идентификацию пользователя, зарегистрированного в докер-хабе и именование образов. Так же, следует выполнить `docker login` для авторизации на докер-хабе

```shell
export USER_NAME=sjotus
docker login
```

Использование make:

```shell
# Собрать все образы (прометеус, экспортер, образы микросервисов)
make
# Запушить образы на докер-хаб (из-за особенности скрипта mongodb-exporter пушится в докер-хаб при сборке)
make push

# Собрать только образы микросервисов
make reddit-micro
# запушить микросервисы в докер-хаб
make push-reddit-micro

# Собрать прометеус и экспортер
make prometheus-all
# Запушить прометеус
make push-prom
```

----
## Homewokr 15 (gitlab-ci-1)
В данном домашнем задании было сделано:
- Установка Gitlab в докере
- Настройка Gitlab
- Настройка Gitlab CI/CD Pipeline
- Тестирование reddit
- Настройка окружений
- Настройка сборки и деплоя в окружение (*)
- Автоматизация развертывания gitlab-ci runner (*)
- Интеграция pipeline со slack (*)

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

Создадим файл с тестом в корне папки reddit с именем simpletest.rb. В `.gitlab-ci.yml` в разделе `test_unit_job` пропиишем вызов этого скрипта.
Теперь при каждом изменении в коде будет запускаться тест.

### Настройка окружений

Настроим dev окружение.
В файле `.gitlab-ci..yml` переименуем stage из deploy в review, а deploy_job в `deploy_dev_job`. Добавим в эту джобу environment:

```yaml
deploy_dev_job:
  stage: review
  script:
    - echo 'Deploy'
  environment:
    name: dev
    url: http://dev.example.com
```

Теперь определим еще 2 окружения: staging и production. В отличии от dev окружения, изменения на них должны выкатываться с кнопки.

```yaml
staging:
  stage: stage
  when: manual
  script:
    - echo 'Deploy'
  environment:
    name: stage
    url: https://beta.example.com
```

Добавим директиву, которая не позволит нам выкатить на staging и production код, не помеченный с помощью тега в git.

```yaml
staging:
  stage: stage
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  script:
    - echo 'Deploy'
...
```

#### Динамические окружения

Гитлаб может динамически созадавать окружения, к примеру окружение для каждой feature ветки. Добавим следующую конфигурацию:

```yaml
branch review:
  stage: review
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment:
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except:
    - master
```

Теперь на каждую ветку, кроме мастера, будет создано окружение

### Настройка сборки и деплоя в окружение (*)
Настроим сборку контейнера с приложением reddit и деплой контейнера на созданный для ветки сервер.

Сначала переделаем общую конфигурацию gitlab-ci.yml. В документации глобальное задание параметров `image, services, cache, before_script, after_script` помечено как deprecated. Их следует задавать через ключевое слово `default`

```yaml
default:
  image: ruby:2.4.2
  before_script:
    - cd reddit
    - bundle install
```

Создадим новый раннер со своим конфигом и зарегистрируем его в не интерактивном режиме. Ранер должен уметь запускать контейнеры в привилегированном режиме.
Не интерактивная регистрация раннера для запуска в привилегированном режиме контейнеров

```shell
docker exec -it gitlab-runner gitlab-runner register \
--non-interactive \
--run-untagged \
--locked=false \
--url http://35.240.96.208/ \
--registration-token mzAo7yQESJKqoQxsZzuZ \
--executor docker \
--description "Privileged Docker runner" \
--docker-image "docker:19.03" \
--docker-privileged \
--tag-list "docker,linux,dind"
```

В каталоге reddit создадим Dockerfile с описанием сборки.
В настройках репозитория -> CI/CD -> Variables создадим 2 переменные `DOCKER_LOGIN` и `DOCKER_PASS` для того, что бы можно было подключиться к докер-хабу. Переменную `DOCKER_PASS` необходимо сделать masked

Начиная с версии 18.06 докера они включили поддержку tls по умолчанию. И докер слушает шифрованный трафик по порту 2376 вместо 2375. Для того, что бы контейнер с докером запустился без шифрования, необходимо переедать переменную окружения без значения

```
DOCKER_TLS_CERTDIR=""
```
Так же можно передать другую переменную окружения, что бы докер точно взял порт 2375 и подключение выполнялось по нему

```
DOCKER_HOST=tcp://docker:2375
```

Эти переменные необходимо указать в .gitlab-ci.yml. 
Логика сборки следующая:
- собираем образ командой docker build
- тегируем образ
- логинимся в докер-хаб
- пушим тегированный образ в докер хаб

Для успешного деплоя, необходимо настроить докер-демон на хостовой машине. Необходимо, что бы помимо unix-сокета он слушал tcp-сокет. Т.к. демон управляется systemd, то что бы не править дефолтный юнит, сделаем оверрайд-конфигурацию.
Создадим файлы в `/etc/systemd/system/docker.service.d/override.conf`

```
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// -H tcp://0.0.0.0:2375 --containerd=/run/containerd/containerd.sock
```

Перечитываем конфигурацию systemd и перезапускаем сервис

```shell
sudo systemctl daemon-reload
sudo systemctl restart docker.service
```

В шаге деплоя указываем переменную `DOCKER_HOST: tcp://$CI_SERVER_HOST:2375` и в качестве скрипта запуск контейнера из докер-хаба.

Так же, необходимо создать правило фаервола в GCP, разрешающее подключение по порту 2375 к машине с докер-хостом.


### Автоматизация развертывания gitlab-ci runner (*)
Для автоматизации развертывания и регистрации раннера будем использовать ансибл. Создадим директорию gitlab-ci, а внутри папку ansible.

Для установки и регистрации раннера на виртуальных машинах будем использовать роль из ansible-galaxy `riemers.gitlab-runner`. Создадим файл requirements.yml в котором опишем используемую роль.

Теперь достаточно выполнить команду

``` shell
asible-galaxy install -r requiements.yml
```
Для установки роли.

Создадим папку playbooks, а в ней файл gitlab-runner.yml в котором опишем установку раннера через используемую роль. Переменные, которые описывают усановку и регистрацию ранера поместим в файл `vars/gitlab-runner.yml`

Теперь для установки и регистрации раннера на хосты, нам достаточно выполнить команду:

```shell
ansible-playbook playbooks/gitlab-runner.yml
```

### Интеграция pipeline со slack (*)

Переходим по ссылке: https://devops-team-otus.slack.com/apps/A0F7XDUAZ-incoming-webhooks?next_id=0

Нажимаем кнопку **Add Configuration**. Выбираем свой канал и нажимаем на кнопку **Add Intergration**. Копируем ссылку из поля **Webhook URL**. Нажимаем **Save Settings**.

Теперь идем в гитбал в проект settings -> integration и находим там пункт **slack notification**.
Чекаем Active. В поле Webhook вставляем скопированную ссылку. В поле Username пишем Gitlab. Снимаем галочку "Notify only default branch". Можно так же снять "Notify only broken pipelines". В списке оставляем с галочками только то, что нам нужно и указываем канал.

Сохраняемся и ... PROFIT!!

[Канал с интеграцией](https://devops-team-otus.slack.com/messages/CK8QN21S6)

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
