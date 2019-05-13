{% set processes = {'journal-cms-article-import': 1, 'journal-cms-send-notifications': 1} %}

{% if salt['grains.get']('osrelease') in ['14.04', '16.04'] %}

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
            - file: {{ process }}-init
            {% endfor %}

journal-cms-processes-start:
    cmd.run:
        - name: start journal-cms-processes
        - require:
            - journal-cms-processes-task

{% else %}

{% set controller = "journal-cms-processes" %}

{{ controller }}-script:
    file.managed:
        - name: /opt/{{ controller }}.sh
        - source: salt://elife/config/etc-init-multiple-processes-parallel.conf
        - template: jinja
        - context:
            processes: {{ processes }}
            timeout: 70

{{ controller }}-service:
    file.managed:
        - name: /lib/systemd/system/{{ controller }}.service
        - source: salt://journal-cms/config/lib-systemd-system-{{ controller }}.service

    service.running:
        - name: {{ controller }}
        - require:
            - file: {{ controller }}-service
            - {{ controller }}-script
            {% for process in processes %}
            - file: {{ process }}-init
            {% endfor %}
            

{% endif %}
