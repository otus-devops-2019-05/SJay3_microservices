# сборка и пушинг докер образов
# Имя пользователя на докер-хабе
DOCKER_REGISTRY = $(USER_NAME)
# Тегирование образов
IMAGE_TAG = $(TAG)

## BUILD SECTION
all: reddit-micro prometheus-all logging

# Reddit
reddit-micro: comment post ui

comment:
	cd src/comment && /bin/bash docker_build.sh

post:
	cd src/post-py && /bin/bash docker_build.sh

ui:
	cd src/ui && /bin/bash docker_build.sh

# MONITORING
prometheus-all: prometheus mongodb-exporter alertmanager telegraf grafana trickster

prometheus:
	cd monitoring/prometheus && docker build -t $(DOCKER_REGISTRY)/prometheus .

trickster:
	cd monitoring/trickster && docker build -t $(DOCKER_REGISTRY)/trickster .

mongodb-exporter:
	cd monitoring/exporters && /bin/bash mongodb_exporter.sh

alertmanager:
	cd monitoring/alertmanager && docker build -t $(DOCKER_REGISTRY)/alertmanager .
telegraf:
	cd monitoring/exporters/telegraf && docker build -t $(DOCKER_REGISTRY)/telegraf .

# Grafana
grafana:
	cd monitoring/grafana && docker build -t $(DOCKER_REGISTRY)/grafana .

# LOGGING
logging: fluentd

fluentd:
	cd logging/fluentd && docker build -t $(DOCKER_REGISTRY)/fluentd .

## PUSH SECTION
# mongodb-exporter пушится в докер-хаб скриптом сразу после сборки
push: push-prom push-reddit-micro push-alert push-telegraf push-grafana push-trickster

push-reddit-micro: push-comment push-post push-ui

push-logging: push-fluentd

push-ui:
	docker push $(DOCKER_REGISTRY)/ui

push-post:
	docker push $(DOCKER_REGISTRY)/post

push-comment:
	docker push $(DOCKER_REGISTRY)/comment

# пуш прометеуса в докер-хаб
push-prom:
	docker push $(DOCKER_REGISTRY)/prometheus

push-alert:
	docker push $(DOCKER_REGISTRY)/alertmanager

push-telegraf:
	docker push $(DOCKER_REGISTRY)/telegraf

push-grafana:
	docker push $(DOCKER_REGISTRY)/grafana

push-trickster:
	docker push $(DOCKER_REGISTRY)/trickster

push-fluentd:
	docker push $(DOCKER_REGISTRY)/fluentd

## TAG SECTION
# тегирование всех образов. Необходимо определить переменную $TAG
tag:
	for var in $$(docker images $(DOCKER_REGISTRY)/*:latest \
		--format "{{.Repository}}"); do \
	docker tag $$var $$var:$(IMAGE_TAG); \
	done;


.PHONY: all prometheus-all reddit-micro comment post ui prometheus mongodb-exporter alertmanager push push-reddit-micro push-ui push-post push-comment push-prom push-alert push-telegraf telegraf grafana push-grafana trickster push-trickster
