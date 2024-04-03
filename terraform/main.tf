variable "az_count" {
  type    = number
  default = 2
}

data "aws_availability_zones" "available" {

}


# ECR

resource "aws_ecr_repository" "resnet18" {
  name = "resnet18"
}

# VPC

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "resnet-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2b"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]


  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

# security group

resource "aws_security_group" "resnet18_sg" {
  name   = "resnet18_sg"
  vpc_id = module.vpc.vpc_id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb_sg" {
  vpc_id = module.vpc.vpc_id
  name   = "lb_sg"

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}



# IAM
data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"

  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "resnet_task_role" {
  name               = "resnet-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.resnet_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# lb
resource "aws_alb" "resnet_alb" {
  name               = "resnet-alb"
  subnets            = module.vpc.public_subnets
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  internal           = false

}


resource "aws_lb_listener" "http_forward" {
  load_balancer_arn = aws_alb.resnet_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.resnet_tg.arn
      }
    }
  }
}

resource "aws_lb_target_group" "resnet_tg" {
  vpc_id                = module.vpc.vpc_id
  name                  = "resnet-alb-tg"
  port                  = 8080
  protocol              = "HTTP"
  target_type           = "ip"
  deregistration_delay  = 30

  health_check {
    interval            = 120
    path                = "/ping"
    timeout             = 60
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  lifecycle {
    create_before_destroy = true
  }
}



# ECS
resource "aws_ecs_task_definition" "resnet_task" {
  family                   = "resnet"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.resnet_task_role.arn
  container_definitions = jsonencode(
    [
      {
        "name" : "resnet",
        "image" : "${aws_ecr_repository.resnet18.repository_url}:latest",
        "cpu" : 1024,
        "memory" : 2048,
        "essential" : true,
        "portMappings" : [
          {
            "containerPort" : 8080,
            "hostPort" : 8080
          }
        ]
      }
    ]
  )
}


resource "aws_ecs_cluster" "resnet_cluster" {

  name = "resnet_cluster"

}


resource "aws_ecs_service" "resnet_service" {
  name                 = "resnet_service"
  cluster              = aws_ecs_cluster.resnet_cluster.id
  desired_count        = 1
  task_definition      = aws_ecs_task_definition.resnet_task.arn
  force_new_deployment = true
  launch_type          = "FARGATE"



  network_configuration {
    assign_public_ip = true
    security_groups  = [aws_security_group.resnet18_sg.id]
    subnets          = module.vpc.public_subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.resnet_tg.arn
    container_name = "resnet"
    container_port = 8080
    
  }

  depends_on = [
    aws_ecs_task_definition.resnet_task
  ]

}
