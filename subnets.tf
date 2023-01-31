resource "aws_subnet" "lab_az1" {
  vpc_id = aws_vpc.lab.id

  map_public_ip_on_launch = true

  cidr_block = "10.0.1.0/24"

  availability_zone_id = "use1-az1"
  # replace with "use2-az1" for us-east-2, or "usw2-az1" for us-west-2

  tags = {
    Name = "${var.owner}-Managed-az1"
  }
}
