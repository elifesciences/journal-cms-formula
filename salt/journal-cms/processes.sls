{% set processes = {'journal-cms-article-import': 1, 'journal-cms-send-notifications': 1} %}

{% if salt['grains.get']('osrelease') == '14.04' %}

# upstart, 12.04, 14.04

{% for process in processes %}
{{ process }}-init:
    file.managed:
        - name: /etc/init/{{ process }}.conf
        - source: salt://journal-cms/config/etc-init-{{ process }}.conf
        - template: jinja
        - require:
            - migrate-content
            - aws-credentials-cli
        - require_in:
            - file: journal-cms-processes-task
{% endfor %}

journal-cms-processes-task:
    file.managed:
        - name: /etc/init/journal-cms-processes.conf
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}
            timeout: 70

journal-cms-processes-start:
    cmd.run:
        - name: start journal-cms-processes
        - require:
            - journal-cms-processes-task

{% else %}

# systemd, 16.04, 18.04

# todo: deprecated.
{% set controller = "journal-cms-processes" %}
{{ controller }}-script:
    file.absent:
        - name: /opt/{{ controller }}.sh

{% for process, num_processes in processes.items() %}
{{ process }}-template:
    file.managed:
        - name: /lib/systemd/system/{{ process }}@.service
        - source: salt://journal-cms/config/lib-systemd-system-{{ process }}@.service
        - template: jinja
        - context:
            process: {{ process }}
        - require:
            - migrate-content
            - aws-credentials-cli
{% endfor %}

{% endif %}
