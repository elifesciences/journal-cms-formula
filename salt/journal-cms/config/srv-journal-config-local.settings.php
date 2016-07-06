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
    '^elife-2.0-website.dev$',
    '^elifesciences\.org$',
    '^.+\.elifesciences\.org$',
);
