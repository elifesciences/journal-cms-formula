#!/bin/bash
# restore a production backup of journal-cms onto any instance
set -exv

cd /opt/ubr/

# downloads
./ubr.sh download s3 adhoc journal-cms/201705/20170522_prod--journal-cms.elifesciences.org_230509-archive-b47198f6.tar.gz
./ubr.sh download s3 adhoc journal-cms/201705/20170522_prod--journal-cms.elifesciences.org_230506-elife_2_0-mysql.gz

# restore MySQL
./ubr.sh restore file adhoc /ext/tmp/ubr/20170522_prod--journal-cms.elifesciences.org_230506-elife_2_0-mysql.gz mysql-database.elife_2_0
# restore files, primarily in /srv/journal-cms/web/sites/default/files/
tar -xvzf /ext/tmp/ubr/20170522_prod--journal-cms.elifesciences.org_230509-archive-b47198f6.tar.gz --directory /
