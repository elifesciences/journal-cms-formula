journal-cms-repository:
    git.latest:
        - name: git@github.com:elifesciences/elife-2.0-website.git
        - identity: {{ pillar.elife.deploy_user.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/journal-cms/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True

    file.directory:
        - name: /srv/journal-cms
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - recurse:
            - user
            - group
        - require:
            - git: journal-cms-repository


composer-install:
    cmd.run:
        - name: composer --no-interaction install
        - cwd: /srv/journal-cms
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - journal-cms-repository

site-settings:
    file.managed:
        - name: /srv/journal-cms/config/local-settings.php
        - source: salt://journal-cms/config/srv-journal-config-local-settings.php
        - template: jinja
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - composer-install

journal-cms-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/journal-cms.conf
        - source: salt://journal-cms/config/etc-nginx-sites-enabled-journal-cms.conf
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

{% for key in ['db', 'legacy_db'] %}
{% set db = pillar.journal_cms[key] %}
journal-cms-{{ key }}:
    mysql_database.present:
        - name: {{ db.name }}
        - connection_pass: {{ pillar.elife.db_root.password }}

journal-cms-{{ key }}-user:
    mysql_user.present:
        - name: {{ db.user }}
        - password: {{ db.password }}
        - connection_pass: {{ pillar.elife.db_root.password }}
        - host: localhost
        - require:
            - service: mysql-server

journal-cms-{{ key }}-access:
    mysql_grants.present:
        - user: {{ db.user }}
        - database: {{ db.name }}.*
        - grant: all privileges
        - connection_pass: {{ pillar.elife.db_root.password }}
        - require:
            - mysql_user: journal-cms-{{ key }}-user
            - mysql_database: journal-cms-{{ key }}
{% endfor %}
