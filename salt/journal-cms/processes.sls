{% set processes = {'journal-cms-article-import': 1, 'journal-cms-send-notifications': 1} %}

{% if salt['grains.get']('osrelease') == '14.04' %}

# upstart, 12.04, 14.04

journal-cms-processes-task:
    file.managed:
        - name: /etc/init/journal-cms-processes.conf
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}
            timeout: 70
        - require:
            {% for process, _number in processes.items() %}
            - file: {{ process }}-init
            {% endfor %}

journal-cms-processes-start:
    cmd.run:
        - name: start journal-cms-processes
        - require:
            - journal-cms-processes-task

{% else %}

# systemd, 16.04, 18.04

{% set controller = "journal-cms-processes" %}

{{ controller }}-script:
    file.absent:
        - name: /opt/{{ controller }}.sh

{% for process, num_processes in processes.items() %}
{{ process }}-service:
    service.running:
        - name: {{ process }}@{1..{{ num_processes }}}
        - enable: true
        - require:
            - file: {{ process }}-init
{% endfor %}

{% endif %}
