# сборка и пушинг докер образов
# Имя пользователя на докер-хабе
DOCKER_REGISTRY = $(USER_NAME)

all: reddit-micro prometheus-all

reddit-micro: comment post ui

comment:
	cd src/comment && docker_build.sh

post:
	cd src/post-py && docker_build.sh

ui:
	cd src/ui && docker_build.sh

prometheus-all: prometheus mongodb-exporter

prometheus:
	cd monitoring/prometheus && docker build -t $(DOCKER_REGISTRY)/prometheus .

mongodb-exporter:
	cd monitoring/exporters && mongodb_exporter.sh

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
