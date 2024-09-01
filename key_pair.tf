resource "tls_private_key" "ecs_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ecs_key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.ecs_key_pair.public_key_openssh

  tags = {
    Name = var.key_pair_name
  }
}