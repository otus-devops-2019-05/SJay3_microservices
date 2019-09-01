#!/bin/bash
git clone https://github.com/percona/mongodb_exporter
cd mongodb_exporter && docker build -t $USER_NAME/mongodb-exporter .
docker push $USER_NAME/mongodb-exporter
