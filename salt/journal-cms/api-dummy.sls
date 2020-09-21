api-dummy-nginx-vhost-dev:
    file.managed:
        - name: /etc/nginx/sites-enabled/api-dummy-dev.conf
        - source: salt://journal-cms/config/etc-nginx-sites-enabled-api-dummy-dev.conf
        - require:
            - api-dummy-composer-install
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

api-dummy-smoke-tests:
    cmd.run:
        - cwd: /srv/api-dummy
        - runas: {{ pillar.elife.deploy_user.username }}
        - name: ./smoke_tests.sh
        - require:
            - api-dummy-nginx-vhost-dev
