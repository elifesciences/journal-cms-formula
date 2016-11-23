{% set processes = {'article-import': 1} %}
{% for process, number in processes.iteritems() %}
journal-cms-{{ process }}-task:
    file.managed:
        - name: /etc/init/journal-cms-{{ process }}s.conf
        - source: salt://elife/config/etc-init-multiple-processes.conf
        - template: jinja
        - context:
            process: journal-cms-{{ process }}
            number: {{ number }}
        - require:
            - file: journal-cms-{{ process }}-service

journal-cms-{{ process }}-start:
    cmd.run:
        - name: start journal-cms-{{ process }}s
        - require:
            - journal-cms-{{ process }}-task
{% endfor %}
