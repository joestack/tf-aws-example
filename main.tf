##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-1"
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #


resource "aws_vpc" "hashicorp" {
  cidr_block           = "${var.network_address_space}"
  enable_dns_hostnames = "true"

  tags {
          Name = "Hashicorp Demo VPC"
  }

}

resource "aws_subnet" "dmz_subnet" {
  vpc_id                  = "${aws_vpc.hashicorp.id}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, 1)}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
          Name = "DMZ Subnet"
  }

}

resource "aws_subnet" "db_subnet" {
  count                   = "${var.db_subnet_count}"
  vpc_id                  = "${aws_vpc.hashicorp.id}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 11)}"
  map_public_ip_on_launch = "false"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index % local.modulus_az]}"

  tags {
          Name = "DB Subnet"
  }

}


resource "aws_subnet" "web_subnet" {
  count                   = "${var.web_subnet_count}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 101)}"
  vpc_id                  = "${aws_vpc.hashicorp.id}"
  map_public_ip_on_launch = "false"
  #availability_zone       = "${data.aws_availability_zones.available.names[count.index % local.modulus_az]}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index % local.modulus_az]}"

  tags {
          Name = "Private WEB Subnet"
  }

}

# necessary if you want to use a ELB with workers in a private subnet
# needs a public subnet in the same AZ as the private subnet
# If there are 6 AZ in your Region you only need up to 6 public subnets
## ToDo: limit the count to the amount of AZ within Region
## FIX: Just create the final amount of public web subnets (modulus_az)
resource "aws_subnet" "pub_web_subnet" {
#  count                   = "${var.web_subnet_count}"
#  count                   = "${var.web_subnet_count > local.modulus_az ? local.modulus_az  : var.web_subnet_count}"
  count                   = "${local.modulus_az}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, count.index + 201)}"
  vpc_id                  = "${aws_vpc.hashicorp.id}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index % local.modulus_az]}"

  tags {
          Name = "Public WEB Subnet"
  }

}



# ROUTING #


resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.hashicorp.id}"

}

resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.hashicorp.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

    tags {
        Name = "IGW"
    }

}

resource "aws_route_table_association" "dmz-subnet" {
  subnet_id      = "${aws_subnet.dmz_subnet.*.id[0]}"
  route_table_id = "${aws_route_table.rtb.id}"

}

# limit the amout of public web subnets to the amount of AZ
resource "aws_route_table_association" "pub_web-subnet" {
  count          = "${local.modulus_az}"
  subnet_id      = "${element(aws_subnet.pub_web_subnet.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtb.id}"

}

resource "aws_route_table" "rtb-nat" {
    vpc_id = "${aws_vpc.hashicorp.id}"

    route {
        cidr_block = "0.0.0.0/0"
        instance_id = "${aws_instance.nat.id}"
    }

    tags {
        Name = "NATinstance"
    }
}

resource "aws_route_table_association" "rtb-db" {
    count          = "${var.db_subnet_count}"
    subnet_id      = "${element(aws_subnet.db_subnet.*.id, count.index)}"
    route_table_id = "${aws_route_table.rtb-nat.id}"
}


resource "aws_route_table_association" "rtb-web" {
    count          = "${var.web_subnet_count}"
    subnet_id      = "${element(aws_subnet.web_subnet.*.id, count.index)}"
    route_table_id = "${aws_route_table.rtb-nat.id}"
}





# SECURITY GROUPS #
# Jumphost security group

resource "aws_security_group" "jumphost" {
  name        = "jumphost"
  vpc_id      = "${aws_vpc.hashicorp.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}


# NAT Instance SG
resource "aws_security_group" "nat" {
  name        = "nat"
  vpc_id      = "${aws_vpc.hashicorp.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DBNODES SG
resource "aws_security_group" "dbnodes" {
  name        = "dbnodes"
  vpc_id      = "${aws_vpc.hashicorp.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# WEBNODES SG
resource "aws_security_group" "webnodes" {
  name        = "webnodes"
  vpc_id      = "${aws_vpc.hashicorp.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# LOADBALANCER SG 
resource "aws_security_group" "elb-sg" {
  name        = "nginx_elb_sg"
  vpc_id      = "${aws_vpc.hashicorp.id}"

  #Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# LOAD BALANCER #
resource "aws_elb" "web-elb" {
  name = "web-elb"


  subnets         = ["${aws_subnet.pub_web_subnet.*.id}"]
  security_groups = ["${aws_security_group.elb-sg.id}"]
  instances       = ["${aws_instance.webnodes.*.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

}




#
# INSTANCES #

resource "aws_instance" "jumphost" {
  ami                         = "ami-c58c1dd3"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.dmz_subnet.id}"
  private_ip                  = "192.168.1.100"
  associate_public_ip_address = "true" 
  vpc_security_group_ids      = ["${aws_security_group.jumphost.id}"]
  key_name                    = "${var.key_name}"

}

resource "aws_instance" "nat" {
  ami                         = "ami-01623d7b"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.dmz_subnet.id}"
  associate_public_ip_address = "true" 
  vpc_security_group_ids      = ["${aws_security_group.nat.id}"]
  key_name                    = "${var.key_name}"
  source_dest_check           = false

  tags {
         Name = "NAT"
  }

}

resource "aws_eip" "nat" {
    instance = "${aws_instance.nat.id}"
    vpc = true

}

resource "aws_instance" "dbnodes" {
  count                       = "${var.dbnodes_count}"
  ami                         = "ami-c58c1dd3"
  instance_type               = "t2.micro"
  subnet_id                   = "${element(aws_subnet.db_subnet.*.id, count.index + 1)}"
  associate_public_ip_address = "false"
  vpc_security_group_ids      = ["${aws_security_group.dbnodes.id}"]
  key_name                    = "${var.key_name}"

  tags {
         Name = "${format("dbnodes-%02d", count.index + 1)}"

  }

}


resource "aws_instance" "webnodes" {
  count                       = "${var.webnodes_count}"
  ami                         = "ami-c58c1dd3"
  instance_type               = "t2.micro"
  subnet_id                   = "${element(aws_subnet.web_subnet.*.id, count.index + 1)}"
  associate_public_ip_address = "false"
  vpc_security_group_ids      = ["${aws_security_group.webnodes.id}"]
  key_name                    = "${var.key_name}"

  tags {
         Name = "${format("webnode-%02d", count.index + 1)}"

  }

}


resource "null_resource" "ansible_run" {
  depends_on = ["local_file.ansible_inventory","aws_internet_gateway.igw","aws_eip.nat","aws_route_table_association.rtb-web"]

  provisioner "local-exec" {
    command     = "sleep 60 && ansible-playbook -i inventory playbook.yml --private-key ${var.private_key_path}"
    working_dir = "${path.module}/ansible/"
  }

}
