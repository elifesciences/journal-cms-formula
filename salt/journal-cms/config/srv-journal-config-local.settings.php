<?php
$databases = array();
$databases['default']['default'] = array(
    'driver' => 'mysql',
    'database' => '{{ pillar.journal_cms.db.name }}',
    'username' => '{{ pillar.journal_cms.db.user }}',
    'password' => '{{ pillar.journal_cms.db.password }}',
    'host' =>     '{{ salt['elife.cfg']('cfn.outputs.RDSHost') or 'localhost' }}',
    'prefix' => '',
    'port' =>     '{{ salt['elife.cfg']('cfn.outputs.RDSPort') or '3306' }}',
    'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
    'driver' => 'mysql',
);

$settings['trusted_host_patterns'] = array(
    '.*',
);

if (class_exists(\Composer\Autoload\ClassLoader::class)) {
  $loader = new \Composer\Autoload\ClassLoader();
  $loader->addPsr4('Drupal\\redis\\', 'modules/redis/src');
  $loader->register();
  $settings['bootstrap_container_definition'] = [
    'parameters' => [],
    'services' => [
      'cache.container' => [
        'class' => 'Drupal\redis\Cache\PhpRedis',
        'factory' => ['@cache.backend.redis', 'get'],
        'arguments' => ['container', '@redis', '@cache_tags_provider.container', '@serialization.phpserialize'],
      ],
      'cache_tags_provider.container' => [
        'class' => 'Drupal\redis\Cache\RedisCacheTagsChecksum',
        'arguments' => ['@redis.factory'],
      ],
      'redis' => [
        'class' => 'Redis',
      ],
      'cache.backend.redis' => [
        'class' => 'Drupal\redis\Cache\CacheBackendFactory',
        'arguments' => ['@redis.factory', '@cache_tags_provider.container', '@serialization.phpserialize'],
      ],
      'redis.factory' => [
        'class' => 'Drupal\redis\ClientFactory',
      ],
      'serialization.phpserialize' => [
        'class' => 'Drupal\Component\Serialization\PhpSerialize',
      ],
    ],
  ];
}

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

if (file_exists(DRUPAL_ROOT . '/../config/local.services.yml')) {
  $settings['container_yamls'][] = DRUPAL_ROOT . '/../config/local.services.yml';
}

{% if pillar.journal_cms.files.private_path %}
$settings['file_private_path'] = '{{ pillar.journal_cms.files.private_path }}';
{% endif %}

{% if pillar.journal_cms.aws.endpoint %}
$settings['jcms_sqs_endpoint'] = '{{ pillar.journal_cms.aws.endpoint }}';
{% else %}
$settings['jcms_sqs_endpoint'] = null;
{% endif %}
$settings['jcms_sqs_queue'] = '{{ pillar.journal_cms.aws.queue }}';
$settings['jcms_sqs_region'] = '{{ pillar.journal_cms.aws.region }}';
$settings['jcms_sns_topic_template'] = '{{ pillar.journal_cms.aws.topic_template }}';
$settings['jcms_gateway'] = '{{ pillar.journal_cms.api.gateway }}';
$settings['jcms_articles_endpoint_for_migration'] = '{{ pillar.journal_cms.api.articles_endpoint_for_migration }}';
$settings['jcms_articles_endpoint'] = '{{ pillar.journal_cms.api.articles_endpoint }}';
$settings['jcms_metrics_endpoint'] = '{{ pillar.journal_cms.api.metrics_endpoint }}';
$settings['jcms_all_articles_endpoint'] = '{{ pillar.journal_cms.api.all_articles_endpoint }}';
$settings['jcms_article_fragment_images_endpoint'] = '{{ pillar.journal_cms.api.article_fragment_images_endpoint }}';
{% if pillar.journal_cms.api.auth_unpublished %}
$settings['jcms_article_auth_unpublished'] = '{{ pillar.journal_cms.api.auth_unpublished }}';
{% else %}
$settings['jcms_article_auth_unpublished'] = null;
{% endif %}

{% if pillar.journal_cms.iiif.base_uri %}
$settings['jcms_iiif_base_uri'] = '{{ pillar.journal_cms.iiif.base_uri }}';
// This folder should be relative to the sites/default/files folder.
$settings['jcms_iiif_mount'] = '{{ pillar.journal_cms.iiif.mount }}';
{% else %}
$settings['jcms_iiif_base_uri'] = null;
{% endif %}
$settings['jcms_rest_cache_max_age'] = 300;
