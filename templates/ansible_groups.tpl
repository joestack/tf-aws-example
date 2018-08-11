[all:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -W %h:%p -q ${ssh_user_name}@${jump_host_ip}"'


[webnodes]
${web_hosts_def}

[dbnodes]
${db_hosts_def}
