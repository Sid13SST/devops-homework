# ----------------------------------------------------------------- EC2 instance
resource "aws_instance" "web" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  tags = {
    Name        = "${var.project}-web"
    Environment = var.environment
    Tier        = "web"
  }
}
