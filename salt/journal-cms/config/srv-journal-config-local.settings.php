<?php
$databases = array();
$databases['default']['default'] = array(
    'driver' => 'mysql',
    'database' => '{{ pillar.journal_cms.db.name }}',
    'username' => '{{ pillar.journal_cms.db.user }}',
    'password' => '{{ pillar.journal_cms.db.password }}',
    'host' => 'localhost',
    'prefix' => '',
    'port' => '3306',
    'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
    'driver' => 'mysql',
);
$databases['legacy_cms']['default'] = array(
    'driver' => 'mysql',
    'database' => '{{ pillar.journal_cms.legacy_db.name }}',
    'username' => '{{ pillar.journal_cms.legacy_db.user }}',
    'password' => '{{ pillar.journal_cms.legacy_db.password }}',
    'host' => 'localhost',
    'prefix' => '',
    'port' => '3306',
    'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
    'driver' => 'mysql',
);

$settings['trusted_host_patterns'] = array(
    '.*',
);

{% if pillar.journal_cms.aws.endpoint %}
$settings['jcms_sqs_endpoint'] = '{{ pillar.journal_cms.aws.endpoint }}';
{% else %}
$settings['jcms_sqs_endpoint'] = null;
{% endif %}
$settings['jcms_sqs_queue'] = '{{ pillar.journal_cms.aws.queue }}';
$settings['jcms_sqs_region'] = '{{ pillar.journal_cms.aws.region }}';
$settings['jcms_sns_topic_template'] = '{{ pillar.journal_cms.aws.topic_template }}';
$settings['jcms_articles_endpoint'] = '{{ pillar.journal_cms.api.articles_endpoint }}';
$settings['jcms_all_articles_endpoint'] = '{{ pillar.journal_cms.api.all_articles_endpoint }}';
{% if pillar.journal_cms.api.auth_unpublished %}
$settings['jcms_article_auth_unpublished'] = '{{ pillar.journal_cms.api.auth_unpublished }}';
{% else %}
$settings['jcms_article_auth_unpublished'] = null;
{% endif %}
{% if pillar.journal_cms.api.auth_published %}
$settings['jcms_article_auth_published'] = '{{ pillar.journal_cms.api.auth_published }}';
{% else %}
$settings['jcms_article_auth_published'] = null;
{% endif %}
