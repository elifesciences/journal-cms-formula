<?php
$databases = array();
$databases['default']['default'] = array(
    'driver' => 'mysql',
    'database' => '{{ salt['elife.cfg']('project.rds_dbname') or pillar.journal_cms.db.name }}',
    'username' => '{{ pillar.journal_cms.db.user }}',
    'password' => '{{ pillar.journal_cms.db.password }}',
    'host' =>     '{{ salt['elife.cfg']('cfn.outputs.RDSHost') or 'localhost' }}',
    'prefix' => '',
    'port' =>     '{{ salt['elife.cfg']('cfn.outputs.RDSPort') or '3306' }}',
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

if (!drupal_installation_attempted()) {
  $settings['cache']['default'] = 'cache.backend.redis';
  $settings['redis.connection']['interface'] = 'PhpRedis';
  $settings['redis.connection']['host'] = '127.0.0.1';
  // Always set the fast backend for bootstrap, discover and config, otherwise
  // this gets lost when redis is enabled.
  $settings['cache']['bins']['bootstrap'] = 'cache.backend.chainedfast';
  $settings['cache']['bins']['discovery'] = 'cache.backend.chainedfast';
  $settings['cache']['bins']['config'] = 'cache.backend.chainedfast';
  $settings['container_yamls'][] = 'modules/redis/example.services.yml';
}
else {
  error_log('Redis cache backend is unavailable.');
}

{% if pillar.journal_cms.aws.endpoint %}
$settings['jcms_sqs_endpoint'] = '{{ pillar.journal_cms.aws.endpoint }}';
{% else %}
$settings['jcms_sqs_endpoint'] = null;
{% endif %}
$settings['jcms_sqs_queue'] = '{{ pillar.journal_cms.aws.queue }}';
$settings['jcms_sqs_region'] = '{{ pillar.journal_cms.aws.region }}';
$settings['jcms_sns_topic_template'] = '{{ pillar.journal_cms.aws.topic_template }}';
$settings['jcms_gateway'] = '{{ pillar.journal_cms.api.gateway }}';
$settings['jcms_articles_endpoint'] = '{{ pillar.journal_cms.api.articles_endpoint }}';
$settings['jcms_all_articles_endpoint'] = '{{ pillar.journal_cms.api.all_articles_endpoint }}';
$settings['jcms_article_fragment_images_endpoint'] = '{{ pillar.journal_cms.api.article_fragment_images_endpoint }}';
{% if pillar.journal_cms.api.auth_unpublished %}
$settings['jcms_article_auth_unpublished'] = '{{ pillar.journal_cms.api.auth_unpublished }}';
{% else %}
$settings['jcms_article_auth_unpublished'] = null;
{% endif %}
