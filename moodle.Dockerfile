FROM bitnami/moodle:4
COPY entrypoint.sh /opt/bitnami/scripts/moodle
COPY setup.sh /opt/bitnami/scripts/apache/