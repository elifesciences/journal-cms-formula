journal_cms:
    db:
        name: elife_2_0
        user: elife_2_0
        password: journal_cms

    logs:
        file_path: private://monolog/

    files:
        private_path: ./../private

    journal:
        base_uri: null
        preview_uri: null

    aws:
        access_key_id: null
        secret_access_key: null
        region: us-east-1
        queue: null
        endpoint: http://10.0.2.2:4100
        topic_template: arn:aws:sns:us-east-1:512686554592:bus-%s--dev

    iiif:
        base_uri: null
        mount: null

    {% set dummy_url = 'http://localhost:8080' %}
    api:
        gateway: null
        articles_endpoint_for_migration: {{ dummy_url }}/articles/%s/versions
        articles_endpoint: {{ dummy_url }}/articles/%s/versions
        metrics_endpoint: {{ dummy_url }}/metrics/article/%s/%s
        all_articles_endpoint: {{ dummy_url }}/articles
        all_digests_endpoint: {{ dummy_url }}/digests
        all_reviewed_preprints_endpoint: {{ dummy_url }}/reviewed-preprints
        article_fragments_endpoint: null
        auth_unpublished: null

    users:
        test_user:
            email: test_user@example.com
            password: test_user
            role: administrator

    consumer_groups_filter:
        api_gateway:
            username: api_gateway_username
            password: api_gateway_password

    restore:
        files: journal-cms/201705/20170522_prod--journal-cms.elifesciences.org_230509-archive-b47198f6.tar.gz
        db: journal-cms/201705/20170522_prod--journal-cms.elifesciences.org_230506-elife_2_0-mysql.gz

elife:
    webserver:
        app: caddy

    php:
        fpm: true
        extra_extensions:
            - redis
            - igbinary
            - uploadprogress
            - sqlite3

    composer:
        version: 2.3.5

    multiservice:
        services:
            journal-cms-article-import:
                service_template: journal-cms-article-import-template
                num_processes: 1
            journal-cms-send-notifications:
                service_template: journal-cms-send-notifications-template
                num_processes: 1
