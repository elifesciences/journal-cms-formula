# backups going forwards
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
    cmd.run:
        - name: |
            apt-get -y --no-install-recommends install php7.0-redis php7.0-igbinary php7.0-uploadprogress 
            {% if pillar.elife.env in ['ci'] %}
            apt-get -y install php7.0-sqlite3
            {% endif %}
        - require:
            - php
        - watch_in:
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
        {% if pillar.elife.env in ['dev', 'ci'] %}
        - require_in:
            - cmd: api-dummy-repository
        {% endif %}

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
        - user: {{ pillar.elife.deploy_user.username }}
        - env:
            - COMPOSER_DISCARD_CHANGES: "1"
        - require:
            - journal-cms-repository
            - install-composer
            - journal-cms-localhost

web-sites-file-permissions:
    cmd.run:
        - name: |
            chmod -f 755 web/sites/default || true
            chmod -f 664 web/sites/default/settings.php || true
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
            - cmd: site-was-installed-check

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
            - cmd: site-was-installed-check

{% for key in ['db'] %}
{% set db = pillar.journal_cms[key] %}
journal-cms-{{ key }}:
    mysql_database.present:
        - name: {{ db.name }}
        {% if salt['elife.cfg']('cfn.outputs.RDSHost') %}
        # remote mysql
        - connection_user: {{ salt['elife.cfg']('project.rds_username') }} # rds 'owner' uname
        - connection_pass: {{ salt['elife.cfg']('project.rds_password') }} # rds 'owner' pass
        - connection_host: {{ salt['elife.cfg']('cfn.outputs.RDSHost') }}
        - connection_port: {{ salt['elife.cfg']('cfn.outputs.RDSPort') }}

        {% else %}
        # local mysql
        - connection_pass: {{ pillar.elife.db_root.password }}

        {% endif %}
        - require:
            - mysql-ready
        - require_in:
            - cmd: site-was-installed-check

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
        - connection_pass: {{ pillar.elife.db_root.password }}
        
        {% endif %}
        - require:
            - mysql-ready
        - require_in:
            - cmd: site-was-installed-check

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
        - connection_pass: {{ pillar.elife.db_root.password }}
        
        {% endif %}
        - require:
            - mysql_user: journal-cms-{{ key }}-user
            - mysql_database: journal-cms-{{ key }}
        - require_in:
            - cmd: site-was-installed-check
{% endfor %}

journal-cms-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/journal-cms.conf
        - source: salt://journal-cms/config/etc-nginx-sites-enabled-journal-cms.conf
        - template: jinja
        - require_in:
            - cmd: site-was-installed-check
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
        - name: /etc/php/7.0/cli/conf.d/20-sendmail.ini
        - source: salt://journal-cms/config/etc-php-7.0-cli-conf.d-20-sendmail.ini
        - require:
            - php
        - require_in:
            - cmd: site-was-installed-check

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
            ../vendor/bin/drush site-install config_installer -y
            ####test -e /home/{{ pillar.elife.deploy_user.username }}/site-was-installed.flag && ../vendor/bin/drush cr || echo "site was not installed before, not rebuilding cache"
            ../vendor/bin/drush cr
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - journal-cms-repository
        ## always perform a new site-install on dev and ci
        {% if pillar.elife.env not in ['dev', 'ci'] %}
        - unless: sudo -u {{ pillar.elife.deploy_user.username}} ../vendor/bin/drush cget system.site name
        {% endif %}

site-update-db:
    cmd.run:
        - name: ../vendor/bin/drush updatedb -y
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - require: 
            - site-install

site-configuration-import:
    cmd.run:
        - name: ../vendor/bin/drush config-import -y
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - require: 
            - site-update-db

site-cache-rebuild-again:
    cmd.run:
        - name: ../vendor/bin/drush cr
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - site-configuration-import

site-permissions-rebuild:
    cmd.run: 
        - name: ../vendor/bin/drush php-eval "node_access_rebuild();"
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
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
            ../vendor/bin/drush mi jcms_subjects_json 2>&1 | tee --append /tmp/drush-migrate.log
            cat /tmp/drush-migrate.log | ../check-drush-migrate-output.sh
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.webserver.username }}
        - require:
            - site-permissions-rebuild

{% for username, user in pillar.journal_cms.users.iteritems() %}
journal-cms-defaults-users-{{ username }}:
    cmd.run:
        - name: |
            ../vendor/bin/drush user-create {{ username }} --mail="{{ user.email }}" --password="{{ user.password }}"
            ../vendor/bin/drush user-add-role "{{ user.role }}" --name={{ username }}
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - unless:
            - sudo -u {{ pillar.elife.deploy_user.username}} ../vendor/bin/drush user-information {{ username }}
        - require:
            - migrate-content
{% endfor %}

{% set processes = ['article-import', 'send-notifications'] %}
{% for process in processes %}
journal-cms-{{ process }}-service:
    file.managed:
        - name: /etc/init/journal-cms-{{ process }}.conf
        - source: salt://journal-cms/config/etc-init-journal-cms-{{ process }}.conf
        - template: jinja
        - require:
            - migrate-content
            - aws-credentials-cli
{% endfor %}

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
