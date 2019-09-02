# сборка и пушинг докер образов
# Имя пользователя на докер-хабе
DOCKER_REGISTRY = $(USER_NAME)

all: reddit-micro prometheus-all

reddit-micro: comment post ui

comment:
	cd src/comment && /bin/bash docker_build.sh

post:
	cd src/post-py && /bin/bash docker_build.sh

ui:
	cd src/ui && /bin/bash docker_build.sh

prometheus-all: prometheus mongodb-exporter

prometheus:
	cd monitoring/prometheus && docker build -t $(DOCKER_REGISTRY)/prometheus .

mongodb-exporter:
	cd monitoring/exporters && /bin/bash mongodb_exporter.sh

# mongodb-exporter пушится в докер-хаб скриптом сразу после сборки
push: push-prom push-reddit-micro

push-reddit-micro: push-comment push-post push-ui

push-ui:
	docker push $(DOCKER_REGISTRY)/ui

push-post:
	docker push $(DOCKER_REGISTRY)/post

push-comment:
	docker push $(DOCKER_REGISTRY)/comment

# пуш прометеуса в докер-хаб
push-prom:
	docker push $(DOCKER_REGISTRY)/prometheus

.PHONY: all prometheus-all reddit-micro comment post ui prometheus mongodb-exporter push push-reddit-micro push-ui push-post push-comment push-prom
