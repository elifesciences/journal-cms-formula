{% set osrelease = salt['grains.get']('osrelease') %}

{% set phpver = "7.2" if osrelease == "18.04" else "7.4" %}

journal-cms-backups:
    file.managed:
        - name: /etc/ubr/journal-cms-backup.yaml
        - source: salt://journal-cms/config/etc-ubr-journal-cms-backup.yaml
        - template: jinja
        - makedirs: True

journal-cms-localhost:
    host.present:
        - ip: 127.0.0.2
        - names:
            - journal-cms.local

journal-cms-php-extensions:
    pkg.installed:
        - skip_suggestions: true
        - install_recommends: false
        - pkgs:
            - php-redis # transitive dependency on apache2 via phpapi-20190902 -> libapache2-mod-php7.4 -> apache2
            - php-igbinary # transitive dependency on apache2 via phpapi-20190902 -> libapache2-mod-php7.4 -> apache2
            # transitive dependency on apache2 via phpapi-20190902 -> libapache2-mod-php7.4 -> apache2
            # *optional* transitive dependency on apache2 via libapache2-mod-php -> libapache2-mod-php7.4 -> apache2
            - php-uploadprogress
            - php{{ phpver }}-sqlite3
        - require:
            - php
            # lsh@2022-11-04: added as we have another instance of apache2 being installed.
            # - https://github.com/elifesciences/issues/issues/7871
            - nginx-server
            - php-nginx-deps
        - listen_in:
            - service: php-fpm

journal-cms-repository:
    builder.git_latest:
        - name: git@github.com:elifesciences/journal-cms.git
        - identity: {{ pillar.elife.projects_builder.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/journal-cms/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
        - require:
            - srv-directory-linked
            - journal-cms-php-extensions

    # file.directory can be a bit slow when recurring over many files
    cmd.run:
        - name: chown -R {{ pillar.elife.deploy_user.username }}:{{ pillar.elife.deploy_user.username }} .
        - cwd: /srv/journal-cms
        - require:
            - builder: journal-cms-repository

# not minimal, but better to be too wide than having strange problems to debug
# TODO: should be moved later in the process? (e.g. after site install)

composer-install:
    cmd.run:
        {% if pillar.elife.env in ['prod', 'end2end', 'continuumtest'] %}
        - name: composer --no-interaction install --optimize-autoloader --no-dev
        {% elif pillar.elife.env != 'dev' %}
        - name: composer --no-interaction install --optimize-autoloader
        {% else %}
        - name: composer --no-interaction install
        {% endif %}
        - cwd: /srv/journal-cms
        - runas: {{ pillar.elife.deploy_user.username }}
        - env:
            - COMPOSER_DISCARD_CHANGES: "1"
        - require:
            - journal-cms-repository
            - install-composer
            - journal-cms-localhost

{# lsh@2021-07-30: disabled to test behaviour of 404 errors in end2end tests

# these files accumulate over time and are not required in non-prod environments.
{% if pillar.elife.env in ['dev', 'ci', 'end2end'] %}
prune-accumulating-files:
    cmd.run:
        - name: rm -rf /srv/journal-cms/web/sites/default/files
        - require:
            - journal-cms-repository
        - require_in:
            - cmd: web-sites-file-permissions
{% endif %}

#}

web-sites-file-permissions:
    cmd.run:
        - name: |
            chmod -f 755 web/sites/default || true
            chmod -f 664 web/sites/default/settings.php || true
            chmod -f 664 web/sites/default/services.yml || true
            mkdir -p web/sites/default/files
            # sanitize all files to be accessible to elife and www-data
            chown -R {{ pillar.elife.webserver.username }}:{{ pillar.elife.webserver.username }} web/sites/default/files
            # new subfolders will inherit the group www-data
            # and with -R even existing subfolders should have the same settings
            chmod -Rf g+ws 664 web/sites/default/files || true
            # only u and g need to write now
            chmod -f 775 web/sites/default/files || true
            # log files will be created here
            mkdir -p private/monolog/
            chown -R www-data:www-data private/monolog
            touch private/monolog/all.json private/monolog/error.json
            chown -R elife:www-data private/monolog/all.json private/monolog/error.json
            chmod 664 private/monolog/all.json private/monolog/error.json
            # log files will inherit the group ownership www-data no matter
            # which user creates them
            chmod g+ws private/monolog
            chmod g+w private/monolog/* || true
        - cwd: /srv/journal-cms
        - require:
            - composer-install

site-settings:
    file.managed:
        - name: /srv/journal-cms/config/local.settings.php
        - source: salt://journal-cms/config/srv-journal-config-local.settings.php
        - template: jinja
        - mode: 664
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - web-sites-file-permissions
        - require_in:
            - file: site-was-installed-check

site-services:
    file.managed:
        - name: /srv/journal-cms/config/local.services.yml
        - source: salt://journal-cms/config/srv-journal-config-local.services.yml
        - template: jinja
        - mode: 664
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - web-sites-file-permissions
        - require_in:
            - file: site-was-installed-check

{% for key in ['db'] %}
{% set db = pillar.journal_cms[key] %}

{% if pillar.elife.env in ['dev', 'ci'] %}
journal-cms-{{ key }}-reset:
    mysql_database.absent:
        - name: {{ db.name }}
        # local mysql only, RDS not supported, don't mess with that
        - connection_pass: {{ pillar.elife.db_root.password }}
        - require_in:
            - mysql_database: journal-cms-{{ key }}
{% endif %}

journal-cms-{{ key }}:
    mysql_database.present:
        - name: {{ db.name }}
        {% if salt['elife.cfg']('cfn.outputs.RDSHost') %}
        # remote mysql
        - connection_user: {{ salt['elife.cfg']('project.rds_username') }} # rds 'owner' uname
        - connection_pass: {{ salt['elife.cfg']('project.rds_password') }} # rds 'owner' pass
        - connection_host: {{ salt['elife.cfg']('cfn.outputs.RDSHost') }}
        - connection_port: {{ salt['elife.cfg']('cfn.outputs.RDSPort') }}
        {% endif %}
        - require:
            - mysql-ready
        - require_in:
            - file: site-was-installed-check

{% if osrelease == "18.04" %}

journal-cms-{{ key }}-user:
    mysql_user.present:
        - name: {{ db.user }}
        - password: {{ db.password }}

        {% if salt['elife.cfg']('cfn.outputs.RDSHost') %}
        # remote mysql
        #- host: '10.0.2.%' # todo, fix this
        - host: '{{ salt['elife.cfg']('project.netmask') }}'
        - connection_user: {{ salt['elife.cfg']('project.rds_username') }} # rds 'owner' uname
        - connection_pass: {{ salt['elife.cfg']('project.rds_password') }} # rds 'owner' pass
        - connection_host: {{ salt['elife.cfg']('cfn.outputs.RDSHost') }}
        - connection_port: {{ salt['elife.cfg']('cfn.outputs.RDSPort') }}

        {% else %}
        # local mysql
        - host: localhost

        {% endif %}
        - require:
            - mysql-ready
        - require_in:
            - file: site-was-installed-check

journal-cms-{{ key }}-access:
    mysql_grants.present:
        - user: {{ db.user }}
        - database: {{ db.name }}.*
        - grant: all privileges

        {% if salt['elife.cfg']('cfn.outputs.RDSHost') %}
        # remote mysql
        #- host: '10.0.2.%' # todo, fix this
        - host: '{{ salt['elife.cfg']('project.netmask') }}'
        - connection_user: {{ salt['elife.cfg']('project.rds_username') }} # rds 'owner' uname
        - connection_pass: {{ salt['elife.cfg']('project.rds_password') }} # rds 'owner' pass
        - connection_host: {{ salt['elife.cfg']('cfn.outputs.RDSHost') }}
        - connection_port: {{ salt['elife.cfg']('cfn.outputs.RDSPort') }}

        {% else %}
        - host: localhost # default

        {% endif %}
        - require:
            - mysql_user: journal-cms-{{ key }}-user
            - mysql_database: journal-cms-{{ key }}
        - require_in:
            - file: site-was-installed-check

{% else %}

# work around for mysql user grants issues with mysql8+ in 20.04.

{% set host = "localhost" if not salt['elife.cfg']('cfn.outputs.RDSHost') else salt['elife.cfg']('project.netmask') %}

journal-cms-{{ key }}-access:
    cmd.script:
        - name: salt://elife/scripts/mysql-auth.sh
        - template: jinja
        - defaults:
            user: "{{ db.user }}"
            pass: "{{ db.password }}"
            host: "{{ host }}"
            db: "{{ db.name }}.*"
            grants: "ALL PRIVILEGES"
        {% if salt['elife.cfg']('cfn.outputs.RDSHost') %}
            connection_user: {{ salt['elife.cfg']('project.rds_username') }} # rds 'owner' uname
            connection_pass: {{ salt['elife.cfg']('project.rds_password') }} # rds 'owner' pass
            connection_host: {{ salt['elife.cfg']('cfn.outputs.RDSHost') }}
            connection_port: {{ salt['elife.cfg']('cfn.outputs.RDSPort') }}
        {% endif %}
        - require:
            - mysql-server

{% endif %}

{% endfor %}

journal-cms-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/journal-cms.conf
        - source: salt://journal-cms/config/etc-nginx-sites-enabled-journal-cms.conf
        - template: jinja
        - require_in:
            - file: site-was-installed-check
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

non-https-redirect:
    file.absent:
        - name: /etc/nginx/sites-enabled/unencrypted-redirect.conf
        - require:
            - journal-cms-vhost

# when more stable, maybe this should be extended to the fpm one?
php-cli-ini-with-fake-sendmail:
    file.managed:
        - name: /etc/php/{{ phpver }}/cli/conf.d/20-sendmail.ini
        - source: salt://journal-cms/config/etc-php-{{ phpver }}-cli-conf.d-20-sendmail.ini
        - require:
            - php
        - require_in:
            - file: site-was-installed-check

site-was-installed-check-flag-remove:
    cmd.run:
        - name: rm -f /home/{{ pillar.elife.deploy_user.username }}/site-was-installed.flag

site-was-installed-check:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/site-was-installed.flag
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - onlyif: cd /srv/journal-cms/web && sudo -u {{ pillar.elife.deploy_user.username}} ../vendor/bin/drush cget system.site name
        - require:
            - site-was-installed-check-flag-remove
        - require_in:
            - cmd: site-install

site-install:
    cmd.run:
        - name: |
            set -e
            ../vendor/bin/drush site-install minimal --existing-config -y
            ####test -e /home/{{ pillar.elife.deploy_user.username }}/site-was-installed.flag && ../vendor/bin/drush cr || echo "site was not installed before, not rebuilding cache"
            #../vendor/bin/drush cr # may fail with "You have requested a non-existent service "cache.backend.redis"
            redis-cli flushall
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - journal-cms-repository
        # always perform a new site-install on dev and ci
        {% if pillar.elife.env not in ['dev', 'ci'] %}
        - unless:
            {% if pillar.elife.env not in ['continuumtest', 'prod'] %}
            - sudo -u {{ pillar.elife.deploy_user.username}} ../vendor/bin/drush cget system.site name
            {% else %}
            # never attempt reinstall on continuumtest or prod
            - false
            {% endif %}
        {% endif %}

site-update-db:
    cmd.run:
        - name: ../vendor/bin/drush updatedb -y
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - site-install

site-configuration-import:
    cmd.run:
        - name: ../vendor/bin/drush config-import -y
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - site-update-db

site-cache-rebuild-again:
    cmd.run:
        - name: ../vendor/bin/drush cr
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - site-configuration-import

site-permissions-rebuild:
    cmd.run:
        - name: ../vendor/bin/drush php-eval "node_access_rebuild();"
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - onlyif: cd /srv/journal-cms/web && [[ $(sudo -u {{ pillar.elife.deploy_user.username }} ../vendor/bin/drush php-eval "print node_access_needs_rebuild()") == "1" ]]
        - require:
            - site-cache-rebuild-again

aws-credentials-cli:
    file.managed:
        - name: /home/{{ pillar.elife.deploy_user.username }}/.aws/credentials
        - source: salt://journal-cms/config/home-user-.aws-credentials
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - makedirs: True
        - template: jinja

aws-credentials-www-data:
    file.managed:
        - name: /var/www/.aws/credentials
        - source: salt://journal-cms/config/home-user-.aws-credentials
        - user: www-data
        - group: www-data
        - makedirs: True
        - template: jinja

# populates data into the labs and subjects until they will be created through the user interface
# TODO: this should fail, but it doesn't because drush fails silently with 0 return code

migrate-content:
    cmd.run:
        - name: |
            rm -f /tmp/drush-migrate.log
            ../vendor/bin/drush migrate:import jcms_subjects_json 2>&1 | tee --append /tmp/drush-migrate.log
            cat /tmp/drush-migrate.log | ../check-drush-migrate-output.sh
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.webserver.username }}
        - require:
            - site-permissions-rebuild

{% for username, user in pillar.journal_cms.users.items() %}
journal-cms-defaults-users-{{ username }}:
    cmd.run:
        - name: |
            ../vendor/bin/drush user-create {{ username }} --mail="{{ user.email }}" --password="{{ user.password }}"
            ../vendor/bin/drush user-add-role "{{ user.role }}" "{{ username }}"
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - unless:
            - sudo -u {{ pillar.elife.deploy_user.username}} ../vendor/bin/drush user-information {{ username }}
        - require:
            - migrate-content
{% endfor %}

# todo: upgrade or remove
journal-cms-warmup-on-boot:
    file.managed:
        - name: /etc/init/journal-cms-warmup.conf
        - source: salt://journal-cms/config/etc-init-journal-cms-warmup.conf
        - template: jinja
        - require:
            - migrate-content
            - aws-credentials-cli

logrotate-monolog:
    file.managed:
        - name: /etc/logrotate.d/journal-cms
        - source: salt://journal-cms/config/etc-logrotate.d-journal-cms

syslog-ng-for-journal-cms-logs:
    file.managed:
        - name: /etc/syslog-ng/conf.d/journal-cms.conf
        - source: salt://journal-cms/config/etc-syslog-ng-conf.d-journal-cms.conf
        - template: jinja
        - require:
            - pkg: syslog-ng
            - site-install
        - listen_in:
            - service: syslog-ng


{% if pillar.elife.env == 'end2end' %}
populate-people-api-with-fixtures:
    cmd.run:
        - name: |
            ../vendor/bin/drush create-person senior-editor "Frankenstein" --given="Victor" --email="victor.frankenstein@ingolstadt.de" --upsert
            ../vendor/bin/drush create-person senior-editor "Brown" --given="Emmett" --email="emmett.brown@hillvalley.usc.edu" --upsert
            ../vendor/bin/drush create-person reviewing-editor "Higgins" --given="Henry" --email="henry.higgins@myfairlady.co.uk" --upsert
            ../vendor/bin/drush create-person reviewing-editor "Calvin" --given="Susan" --email="susan.calvin@usrobots.com" --upsert
        # as late as possible
        - cwd: /srv/journal-cms/web
        - runas: {{ pillar.elife.deploy_user.username }}
        - require:
            - cmd: migrate-content
{% endif %}

# disabled for now, as it leads to journal-cms linking to articles
# that do not exist in lax--end2end
#{% if pillar.elife.env == 'end2end' and  salt['elife.rev']() == 'approved' %}
#restore-backup-from-production:
#    cmd.script:
#        - name: restore-journal-cms-script
#        - source: salt://journal-cms/scripts/restore-journal-cms.sh
#        - template: jinja
#        # as late as possible
#        - require:
#            - cmd: migrate-content
#{% endif %}
