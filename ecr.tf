resource "aws_ecr_repository" "main" {
  name = var.ecr_repository_name

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "main-ecr-repo"
  }
}