journal_cms:
    db:
        name: journal_cms
        user: journal_cms
        password: journal_cms

    legacy_db:
        name: legacy_cms
        user: legacy_cms
        password: legacy_cms

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
        articles_endpoint: null
        all_articles_endpoint: null
        article_fragment_images_endpoint: null
        auth_unpublished: null

    users:
        test_user:
            email: test_user@example.com
            password: test_user
            role: administrator

api_dummy:
    standalone: False
