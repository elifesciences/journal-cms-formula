journal-repository:

    git.latest:
        - name: git@github.com:elifesciences/elife-2.0-website.git
        - identity: {{ pillar.elife.deploy_user.key or '' }}
        - rev: {{ salt['elife.rev']() }}
        - branch: {{ salt['elife.branch']() }}
        - target: /srv/journal/
        - force_fetch: True
        - force_checkout: True
        - force_reset: True
