##################################################################################
# OUTPUT
##################################################################################

output "Jumphost public IP" {
  value = "${aws_instance.jumphost.public_ip}"
}

output "amount of AZ in this Region" {
    value = "${local.modulus_az}"
}

output "aws_elb_public_dns" {
  value = "${aws_elb.web-elb.dns_name}"
}


