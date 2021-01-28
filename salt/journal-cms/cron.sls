journal-cms-cron-cache-rebuild:
    cron.absent:
        - identifier: journal-cms-cron-cache-rebuild
        - name: cd /srv/journal-cms/web && ../vendor/bin/drush cache-rebuild
        - user: {{ pillar.elife.deploy_user.username }}
        - require:
            - migrate-content

journal-cms-cron-drupal:
    cron.present:
        - identifier: journal-cms-cron-drupal
        - name: cd /srv/journal-cms/web && ../vendor/bin/drush core-cron
        - user: {{ pillar.elife.deploy_user.username }}
        - minute: "*/5"
        - require:
            - migrate-content

journal-cms-cron-purge-revisions:
    cron.present:
        - identifier: journal-cms-cron-purge-revisions:
        - name: cd /srv/journal-cms/web && ../vendor/bin/drush paragraphs-revisions-purge --feedback=1000 && ../vendor/bin/drush paragraphs-revisions-optimise
        - user: {{ pillar.elife.deploy_user.username }}
        - hour: 3
        - minute: 0
        - require:
            - migrate-content
