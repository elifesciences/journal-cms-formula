srv-directory:
    file.directory:
        - name: /ext/srv
        - require:
            - mount-external-volume

srv-directory-linked:
    cmd.run:
        - name: mv /srv/* /ext/srv
        - onlyif:
            # /srv/ has something in it to move
            - ls -l /srv/ | grep -v 'total 0'
            - test ! -L /srv
        - require:
            - srv-directory

    file.symlink:
        - name: /srv
        - target: /ext/srv
        - force: True
        - require:
            - cmd: srv-directory-linked

tmp-directory-on-external-volume:
    file.directory:
        - name: /ext/tmp
        - user: {{ pillar.elife.deploy_user.username }}
        - group: {{ pillar.elife.deploy_user.username }}
        - require:
            - mount-external-volume

# backups going forwards
journal-cms-backups:
    file.managed:
        - name: /etc/ubr/journal-cms-backup.yaml
        - source: salt://journal-cms/config/etc-ubr-journal-cms-backup.yaml
        - template: jinja

# used for migrations. lives in a subdir of the ubr config 'restore-only' so 
# we're not constantly restoring a backup of a restore ...
legacy-journal-cms-backups:
    file.managed:
        - name: /etc/ubr/restore-only/journal-cms-legacy-backup.yaml
        - source: salt://journal-cms/config/etc-ubr-restore-only-journal-cms-legacy-backup.yaml
        - makedirs: True
        - template: jinja

journal-cms-localhost:
    host.present:
        - ip: 127.0.0.2
        - names:
            - journal-cms.local

journal-cms-php-extensions:
    pkg.installed:
        - pkgs:
            - php7.0-redis
            - php7.0-uploadprogress
        - install_recommends: False
        - refresh: True
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

# this should have the fix https://github.com/puli/composer-plugin/pull/46
puli-master:
    cmd.run:
        # install 1.0.0-beta10 at the moment
        - name: |
            composer global remove puli/cli
            curl https://puli.io/installer | php
        - cwd: /srv/journal-cms
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - cmd: install-composer
            - journal-cms-repository


# not minimal, but better to be too wide than having strange problems to debug
# TODO: should be moved later in the process? (e.g. after site install)

composer-install:
    cmd.run:
        - name: composer --no-interaction install
        - cwd: /srv/journal-cms
        - user: {{ pillar.elife.deploy_user.username }}
        - env:
            - COMPOSER_DISCARD_CHANGES: "1"
        - require:
            - install-composer
            - journal-cms-localhost
            - puli-master

web-sites-file-permissions:
    cmd.run:
        - name: |
            chmod -f 755 web/sites/default || true
            chmod -f 664 web/sites/default/settings.php || true
            mkdir -p web/sites/default/files
            # sanitize all files to be accessible to elife and www-data
            chown -R {{ pillar.elife.deploy_user.username }}:{{ pillar.elife.webserver.username }} web/sites/default/files
            # new subfolders will inherit the group www-data
            chmod -f g+s 664 web/sites/default/files || true
            # only u and g need to write now
            chmod -f 775 web/sites/default/files || true
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
            - cmd: site-install
            
{% for key in ['db', 'legacy_db'] %}
{% set db = pillar.journal_cms[key] %}
journal-cms-{{ key }}:
    mysql_database.present:
        - name: {{ db.name }}
        - connection_pass: {{ pillar.elife.db_root.password }}
        - require:
            - mysql-ready
        - require_in:
            - cmd: site-install

journal-cms-{{ key }}-user:
    mysql_user.present:
        - name: {{ db.user }}
        - password: {{ db.password }}
        - connection_pass: {{ pillar.elife.db_root.password }}
        - host: localhost
        - require:
            - mysql-ready
        - require_in:
            - cmd: site-install

journal-cms-{{ key }}-access:
    mysql_grants.present:
        - user: {{ db.user }}
        - database: {{ db.name }}.*
        - grant: all privileges
        - connection_pass: {{ pillar.elife.db_root.password }}
        - require:
            - mysql_user: journal-cms-{{ key }}-user
            - mysql_database: journal-cms-{{ key }}
        - require_in:
            - cmd: site-install
{% endfor %}

journal-cms-vhost:
    file.managed:
        - name: /etc/nginx/sites-enabled/journal-cms.conf
        - source: salt://journal-cms/config/etc-nginx-sites-enabled-journal-cms.conf
        - template: jinja
        - require_in:
            - site-install
        - listen_in:
            - service: nginx-server-service
            - service: php-fpm

# when more stable, maybe this should be extended to the fpm one?
php-cli-ini-with-fake-sendmail:
    file.managed:
        - name: /etc/php/7.0/cli/conf.d/20-sendmail.ini
        - source: salt://journal-cms/config/etc-php-7.0-cli-conf.d-20-sendmail.ini
        - require:
            - php
        - require_in:
            - site-install

site-install:
    cmd.run:
        - name: ../vendor/bin/drush si config_installer -y
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        ## always perform a new site-install on dev and ci
        {% if pillar.elife.env not in ['dev', 'ci'] %}
        - unless: ../vendor/bin/drush cget system.site name
        {% endif %}

site-configuration-import:
    cmd.run:
        - name: ../vendor/bin/drush -y cim
        - cwd: /srv/journal-cms/web/
        - user: {{ pillar.elife.deploy_user.username }}
        - require: 
            - site-install

site-update-db:
    cmd.run:
        - name: ../vendor/bin/drush updb -y
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - require: 
            - site-configuration-import


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
migrate-content:
    cmd.run:
        - name: |
            ../vendor/bin/drush mi jcms_labs_experiments_json
            ../vendor/bin/drush mi jcms_subjects_json
        #- name: ../vendor/bin/drush mi --all
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - site-update-db

{% for username, user in pillar.journal_cms.users.iteritems() %}
journal-cms-defaults-users-{{ username }}:
    cmd.run:
        - name: |
            ../vendor/bin/drush user-create {{ username }} --mail="{{ user.email }}" --password="{{ user.password }}"
            ../vendor/bin/drush user-add-role "{{ user.role }}" --name={{ username }}
        - cwd: /srv/journal-cms/web
        - user: {{ pillar.elife.deploy_user.username }}
        - unless:
            - ../vendor/bin/drush user-information {{ username }}
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


# disabled until ubr develop -> master
#restore-legacy-files:
#    cmd.run:
#        - cwd: /opt/ubr
#        - name: |
#            set -e
#            source install.sh
#            python -m ubr.main /etc/ubr/restore-only/ restore file journal-cms--platform.sh "mysql-database.legacy_cms tar-gzipped./scripts/legacy_cms_files/**"
#            touch /root/.legacy-restored.flag
#        - require:
#            - file: journal-cms-backups
#        - unless:
#            - test -e /root/.legacy-restored.flag


