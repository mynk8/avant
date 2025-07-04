#!/usr/bin/bash

set -eux

# $APP defines where's the module (or package)
if [[ -z ${APP} ]]; then
    echo "APP not defined or empty, exiting"
    exit 1
fi

# Whether to run Celery worker or beat (task scheduler)
if [[ "${CELERY_COMMAND:=worker}" == "beat" ]]; then
    # when using the database backend, celery beat must be running for the results to be expired.
    # https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html#starting-the-scheduler
    exec celery --app="${APP}" beat --loglevel="${LOGLEVEL:-DEBUG}" --pidfile=/tmp/celerybeat.pid --schedule=/tmp/celerybeat-schedule

elif [[ "${CELERY_COMMAND}" == "worker" ]]; then
    # define queues to serve
    : "${QUEUES:=default}"
    export QUEUES

    # Number of concurrent worker threads executing tasks.
    : "${CONCURRENCY:=1}"
    export CONCURRENCY

    # Options: solo | prefork | gevent
    # https://www.distributedpython.com/2018/10/26/celery-execution-pool/
    if ((CONCURRENCY > 1)); then
      : "${POOL:=gevent}"
    else
      : "${POOL:=prefork}"
    fi
    export POOL

    # https://docs.celeryq.dev/en/stable/userguide/optimizing.html#optimizing-prefetch-limit
    exec celery --app="${APP}" worker --loglevel="${LOGLEVEL:-DEBUG}" --concurrency="${CONCURRENCY}" --pool="${POOL}" --prefetch-multiplier=1 --queues="${QUEUES}"
fi 