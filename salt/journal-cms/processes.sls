{% set processes = {'journal-cms-article-import': 1, 'journal-cms-send-notifications': 1} %}

journal-cms-processes-task:
    file.managed:
        - name: /etc/init/journal-cms-processes.conf
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}
            timeout: 70
        - require:
            {% for process, _number in processes.iteritems() %}
            - file: {{ process }}-service
            {% endfor %}

journal-cms-processes-start:
    cmd.run:
        - name: start journal-cms-processes
        - require:
            - journal-cms-processes-task
