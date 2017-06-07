#!/bin/bash
# restore a production backup of journal-cms onto any instance
set -exv

cd /opt/ubr/

# downloads
./ubr.sh download s3 adhoc {{ pillar.journal_cms.restore.files }}
./ubr.sh download s3 adhoc {{ pillar.journal_cms.restore.db }}

# restore files, primarily in /srv/journal-cms/web/sites/default/files/
{% set files_basename = salt['file.basename'](pillar.journal_cms.restore.files) %}
tar -xvzf /ext/tmp/ubr/{{ files_basename }} --directory /
# restore MySQL
{% set db_basename = salt['file.basename'](pillar.journal_cms.restore.db) %}
./ubr.sh restore file adhoc /ext/tmp/ubr/{{ db_basename }} mysql-database.elife_2_0
