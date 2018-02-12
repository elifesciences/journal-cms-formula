#
# cron jobs
#
journal-cms-cron-drupal:
    cron.present:
        - identifier: journal-cms-cron-drupal
        - name: cd /srv/journal-cms/web && ../vendor/bin/drush core-cron
        - user: {{ pillar.elife.deploy_user.username }}
        - minute: "*/5"
        - require:
            - migrate-content
