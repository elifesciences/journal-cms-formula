<?php
$databases = array();
$databases['default']['default'] = array(
    'driver' => 'mysql',
    'database' => '{{ pillar.journal_cms.db.name }}',
    'username' => '{{ pillar.journal_cms.db.user }}',
    'password' => '{{ pillar.journal_cms.db.password }}',
    'host' => 'localhost',
    'prefix' => '',
);

$settings['trusted_host_patterns'] = array(
    '.*',
);

$settings['jcms_sqs_endpoint'] = '{{ pillar.journal_cms.aws.endpoint }}';
$settings['jcms_sqs_queue'] = '{{ pillar.journal_cms.aws.queue }}';
$settings['jcms_sqs_region'] = '{{ pillar.journal_cms.aws.region }}';
$settings['jcms_articles_endpoint'] = '{{ pillar.journal_cms.api.articles_endpoint }}';
$settings['jcms_article_auth_unpublished'] = '{{ pillar.journal_cms.api.auth_unpublished }}';
$settings['jcms_article_auth_published'] = '{{ pillar.journal_cms.api.auth_published }}';
