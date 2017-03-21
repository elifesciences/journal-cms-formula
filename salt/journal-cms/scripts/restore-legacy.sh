#!/bin/bash
# restore legacy files. run as root
set -exv

# download the legacy files
cd /opt/ubr/
./ubr.sh download s3 adhoc _platform.sh/legacy_cms.sql.gz _platform.sh/legacy_cms_files.tar.gz

# the database can be handled with ubr
./ubr.sh restore file adhoc /tmp/ubr/legacy_cms.sql.gz mysql-database.legacy_cms

# however the files cannot. a particular way of tar-gzipping them is done with
# ubr that I don't expect others to know or deal with, so we'll just do it manually

# legacy files tar structure looks like:
#   ...
#   legacy_cms_files/js/js_zUchwdBgXyl2MEpwIrRPM3zsQ1yrZnDqG6BJLLLcPjk.js.gz
#   legacy_cms_files/focal_point/test-drive.jpg
#   legacy_cms_files/css/css_-kDRIJTq1NUOhxNE2CKaMA9f8rXeHPYTauG_kHAFoso.css
#   ...

cd /srv/journal-cms/scripts/

# remove anything that may have been restored previous
rm -rf ./legacy_cms_files/ 

# unpack the archive
tar -xvzf /tmp/ubr/legacy_cms_files.tar.gz

# fix up any permissions issues
cd /srv/journal-cms/
chown elife:elife -R ./scripts/

# ensure we don't run the script again
touch /root/legacy-restored.flag

echo "[✓] legacy files restored"
