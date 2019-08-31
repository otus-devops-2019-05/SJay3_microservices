#!/bin/bash
git clone https://github.com/percona/mongodb_exporter
cd mongodb_exporter && docker build -t sjotus/mongodb-exporter .
docker push
