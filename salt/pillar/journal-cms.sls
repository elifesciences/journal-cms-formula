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

    api:
        gateway: null
        articles_endpoint_for_migration: null
        articles_endpoint: null
        metrics_endpoint: null
        all_articles_endpoint: null
        article_fragment_images_endpoint: null
        auth_unpublished: null

    users:
        test_user:
            email: test_user@example.com
            password: test_user
            role: administrator

    restore:
        files: journal-cms/201705/20170522_prod--journal-cms.elifesciences.org_230509-archive-b47198f6.tar.gz
        db: journal-cms/201705/20170522_prod--journal-cms.elifesciences.org_230506-elife_2_0-mysql.gz

api_dummy:
    standalone: False
    pinned_revision_file: /srv/journal-cms/api-dummy.sha1
