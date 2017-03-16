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

legacy-journal-cms-backups:
    file.absent:
        - name: /etc/ubr/restore-only/journal-cms-legacy-backup.yaml

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
            - cmd: site-install

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
            - cmd: site-install

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

{% if salt['elife.cfg']('cfn.outputs.DomainName') %}
non-https-redirect:
    file.symlink:
        - name: /etc/nginx/sites-enabled/unencrypted-redirect.conf
        - target: /etc/nginx/sites-available/unencrypted-redirect.conf
        - require:
            - journal-cms-vhost
{% endif %}

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
# TODO: this should fail, but it doesn't because drush fails silently with 0 return code
# TODO: this needs some legacy database to be restored on this machine to be able to work, ubr should do that
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

# TODO: only in end2end, and whe it works prod
restore-legacy-files:
    cmd.script:
        - name: restore-legacy-script
        - source: salt://journal-cms/scripts/restore-legacy.sh
        - creates: /root/legacy-restored.flag
        - require:
            - journal-cms-legacy_db
            - site-install
