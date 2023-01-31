resource "aws_security_group" "allow_ssh" {
  description = "SSH Inbound"
  name        = "${var.owner}-allow-ssh"
  vpc_id      = aws_vpc.lab.id

  ingress = [{
    description      = null,
    protocol         = "tcp",
    cidr_blocks      = ["0.0.0.0/0"],
    from_port        = 22,
    to_port          = 22,
    ipv6_cidr_blocks = null,
    prefix_list_ids  = null,
    security_groups  = null,
    self             = null
  }]
}

resource "aws_instance" "demo" {
  ami   = var.ami

  instance_type = "t3.xlarge"

  key_name                    = "${var.key}"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.lab_az1.id

  vpc_security_group_ids = [ aws_security_group.allow_ssh.id ]

  root_block_device {
    volume_size = 20
  }
}

output "build" {
  value = {
    ip  = aws_instance.demo.public_ip,
    dns = aws_instance.demo.public_dns,
  }
}