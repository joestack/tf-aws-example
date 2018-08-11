## dynamically generate a `inventory` file for Ansible Configuration Automation 

data "template_file" "ansible_db_hosts" {
    count      = "${var.dbnodes_count}"
    template   = "${file("${path.module}/templates/ansible_hosts.tpl")}"
    depends_on = ["aws_instance.dbnodes"]

      vars {
        ##node_name    = "${aws_instance.webnodes.[${count.index}].tags["Name"]}"
        node_name    = "${lookup(aws_instance.dbnodes.*.tags[count.index], "Name")}"
        ansible_user = "${var.ssh_user}"
        extra        = "ansible_host=${element(aws_instance.dbnodes.*.private_ip,count.index)}"
      }

}

data "template_file" "ansible_web_hosts" {
    count      = "${var.webnodes_count}"
    template   = "${file("${path.module}/templates/ansible_hosts.tpl")}"
    depends_on = ["aws_instance.webnodes"]

      vars {
        ##node_name    = "${aws_instance.webnodes.[${count.index}].tags["Name"]}"
        node_name    = "${lookup(aws_instance.webnodes.*.tags[count.index], "Name")}"
        ansible_user = "${var.ssh_user}"
        extra        = "ansible_host=${element(aws_instance.webnodes.*.private_ip,count.index)}"
      }

}


data "template_file" "ansible_groups" {
    template = "${file("${path.module}/templates/ansible_groups.tpl")}"

      vars {
        jump_host_ip  = "${aws_instance.jumphost.public_ip}"
        ssh_user_name = "${var.ssh_user}"
        web_hosts_def = "${join("",data.template_file.ansible_web_hosts.*.rendered)}"
        db_hosts_def  = "${join("",data.template_file.ansible_db_hosts.*.rendered)}"
      }

}

resource "local_file" "ansible_inventory" {
    content = "${data.template_file.ansible_groups.rendered}"
    filename = "${path.module}/ansible/inventory"

}


