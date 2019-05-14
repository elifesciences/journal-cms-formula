{% set processes = {'journal-cms-article-import': 1, 'journal-cms-send-notifications': 1} %}

{% if salt['grains.get']('osrelease') == '14.04' %}

# upstart, 12.04, 14.04

{% for process, _ in processes %}
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

# old, remove 
{% set controller = "journal-cms-processes" %}
{{ controller }}-script:
    file.absent:
        - name: /opt/{{ controller }}.sh



# new
{% for process, num_processes in processes.items() %}

# https://www.freedesktop.org/software/systemd/man/systemd.target.html
{{ process }}-controller.target:
    # the process controller simply provides a target state that processes can depend on
    # the controller itself is started after reaching the 'multi-user.target'
    file.managed:
        - name: /lib/systemd/system/{{ process }}-controller.target
        - source: salt://journal-cms/templates/process-controller.target

    # ensure the controller is running and should be running on boot
    # stopping+starting this *target* will stop+start the services that depend on it
    service.running:
        - enable: true
        - require:
            - file: {{ process }}-controller.target

# tell systemd we want N number of these template ('instantiated') services enabled and ready to run on boot
# these services will stop/start/restart themselves when the controller they depend on is stopped/started/restarted
enable-n-{{ process }}-services:
    file.managed:
        - name: /lib/systemd/system/{{ process }}@.service
        - source: salt://journal-cms/config/lib-systemd-system-{{ process }}@.service
        - template: jinja
        - context:
            process: {{ process }}
        
    service.running:
        - name: {{ process }}@{1..{{ num_processes }}} # "journal-cms-article-import@{1..1}"
        - init_delay: 5 # seconds. occasionally there is a long pause before failure, sometimes a very short pause
        - require:
            - file: enable-n-{{ process }}-services
            - {{ process }}-controller.target
            - migrate-content
            - aws-credentials-cli

{% endfor %}

{% endif %}
