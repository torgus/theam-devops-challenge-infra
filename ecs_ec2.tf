resource "aws_ecs_cluster" "main" {
  name = var.ecs_cluster_name

  tags = {
    Name = "main-ecs-cluster"
  }
}
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}


resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "ecs-instance-role"
  }
}

resource "aws_iam_policy" "ecs_instance_policy" {
  name        = "ecs-instance-policy"
  description = "Policy for ECS instances to interact with ECS and ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:CreateCluster",
          "ecs:RegisterContainerInstance",
          "ecs:Submit*",
          "ecs:DiscoverPollEndpoint",
          "ecs:Poll",
          "ecs:UpdateContainerInstancesState",
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:ListTasks",
          "ecs:DescribeClusters",
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTasks"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ],
        Resource = "*"
      }
    ]
  })
}

# Asociar la política con el rol
resource "aws_iam_role_policy_attachment" "ecs_instance_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_instance_policy.arn
  role     = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.ecs_cluster_name}-ecs-launch-template"
  image_id       = data.aws_ssm_parameter.ecs_ami.value  
  instance_type  = "t3.micro"  
  key_name        = aws_key_pair.ecs_key_pair.key_name
  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config;
    EOF
  )
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name  
  }

 block_device_mappings {
    device_name = "/dev/xvda"  
    ebs {
      volume_size = 30  
      volume_type = "gp3" 
      delete_on_termination = true 
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    device_index                = 0
    security_groups             = [aws_security_group.ecs.id] 
  }


  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "ecs-launch-template"
  }
}

resource "aws_autoscaling_group" "ecs" {
  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }
  min_size             = 1
  max_size             = 1
  desired_capacity     = 1
  vpc_zone_identifier  = aws_subnet.public_subnet[*].id

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs-task" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    security_groups = [aws_security_group.elb.id] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ecs-task"
  }
}
resource "aws_security_group" "ecs" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ecs-task"
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}


resource "aws_ecs_task_definition" "dummy_app" {
  family                   = "dummy-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  container_definitions    = jsonencode([
    {
      name      = "app-container"
      image     = "amazon/amazon-ecs-sample"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])

  tags = {
    Name = "app-task-definition"
  }
}

resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.dummy_app.arn
  desired_count   = 1
  launch_type     = "EC2"
  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets         =  aws_subnet.public_subnet[*].id
    security_groups = [aws_security_group.ecs-task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "app-container"
    container_port   = 3000
  }

  lifecycle {
    ignore_changes = [
      task_definition
    ]
  }
}