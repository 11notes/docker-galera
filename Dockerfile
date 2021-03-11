# :: Header
    FROM mariadb:10.4
    ENV SST_METHOD=mariabackup

# :: Run
    USER root

    # :: prepare
        COPY qpress-11-linux-x64.tar /tmp/qpress.tar

    # :: install
        RUN set -x \
            && apt-get update \
            && apt-get install -y --no-install-recommends --no-install-suggests \
                curl \
                netcat \
                pigz \
                pv \
            && tar -C /usr/local/bin -xf /tmp/qpress.tar qpress \
            && chmod +x /usr/local/bin/qpress \
            && rm -rf /tmp/* /var/cache/apk/* /var/lib/apt/lists/*

        # :: copy root filesystem changes
            COPY ./rootfs /

        RUN set -ex ;\
            chown -R mysql:mysql /etc/mysql ;\
            chmod -R go-w /etc/mysql ;\
            rm /etc/mysql/conf.d/31-auth-socket.cnf ;\
            sed -i 's#-p \$progress#-p \$progress-XXX#' /usr/bin/wsrep_sst_mariabackup

        RUN chmod +x /usr/local/bin/*

        # :: docker -u 1000:1000 (no root initiative)
            RUN APP_UID="$(id -u mysql)" \
                && APP_GID="$(id -g mysql)" \
                && find / -not -path "/proc/*" -user $APP_UID -exec chown -h -R 1000:1000 {} \;\
                && find / -not -path "/proc/*" -group $APP_GID -exec chown -h -R 1000:1000 {} \;

            RUN usermod -u 1000 mysql \
                && groupmod -g 1000 mysql

            RUN chown -R 1000:1000 \
                /var/lib/mysql \
                /var/run \
                /usr/local

# :: Volumes
    VOLUME ["/var/lib/mysql"]


# :: Monitor
    RUN chmod +x /usr/local/bin/healthcheck.sh
    HEALTHCHECK CMD /usr/local/bin/healthcheck.sh || exit 1


# :: Start
    USER mysql
    ENTRYPOINT ["start.sh"]