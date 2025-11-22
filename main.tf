# Define necessary providers
provider "aws" {
  region = "us-east-1"
}

# Load Balancer Configuration
resource "aws_lb" "main" {
  name               = "main-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]

  enable_deletion_protection = false

  tags = {
    Name = "main-lb"
  }
}

# Target Groups for Blue and Green Deployments
resource "aws_lb_target_group" "blue_tg" {
  name        = "blue-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = {
    Name = "blue-tg"
  }
}

resource "aws_lb_target_group" "green_tg" {
  name        = "green-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  tags = {
    Name = "green-tg"
  }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_tg.arn
  }
   
  depends_on = [aws_lb_target_group.blue_tg]


  lifecycle {

  ignore_changes = [
     default_action
   ]
 }
}

# ECS Cluster
#resource "aws_ecs_cluster" "main" {
#  name = "main-cluster"
#}

/*
# Define Capacity Provider
resource "aws_ecs_capacity_provider" "ec2_capacity_provider" {
  name = "ec2-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.app_asg.arn
    managed_termination_protection = "ENABLED"
  }
}
*/
# Update ECS Cluster to use the Capacity Provider
resource "aws_ecs_cluster" "main" {
   name = "main-cluster"
}

resource "aws_ecs_capacity_provider" "ec2_capacity_provider" {
  name = "ec2-capacity-provider"
  
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.app_asg.arn
    managed_termination_protection = "DISABLED"
  }
}

# Associate ECS Cluster with Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [
    "FARGATE",
    aws_ecs_capacity_provider.ec2_capacity_provider.name
  ]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ec2_capacity_provider.name
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_service_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/app"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

data "aws_ecs_task_definition" "app" {
  task_definition = "app-task"

 depends_on = [aws_ecs_task_definition.app]
}


# ECS Service with Blue/Green Deployment
resource "aws_ecs_service" "app" {
  name            = "app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = data.aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets          = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]
    security_groups  = [aws_security_group.app_sg.id]
    assign_public_ip = false
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue_tg.arn
    container_name   = "app"
    container_port   = 5000
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
      load_balancer
    ]
  }

  depends_on = [aws_lb_listener.http,
#       null_resource.register_task_definition
      ]
}


# CodeDeploy Application
resource "aws_codedeploy_app" "ecs_app" {
  name              = "ecs-app"
  compute_platform  = "ECS"
}

# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "ecs_dg" {
  app_name              = aws_codedeploy_app.ecs_app.name
  deployment_group_name = "ecs-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
 
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"  

    depends_on = [aws_ecs_service.app]

 auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }  


  ecs_service {
    cluster_name        = aws_ecs_cluster.main.name
    service_name        = aws_ecs_service.app.name
  }

  load_balancer_info {
    target_group_pair_info {
      target_group {
        name = aws_lb_target_group.blue_tg.name
      }

      target_group {
        name = aws_lb_target_group.green_tg.name
      }

      prod_traffic_route {
        listener_arns = [aws_lb_listener.http.arn]
      }
    }
  }
}


  
# IAM Roles and Policies
# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Policy Attachment for ECS Task Role
resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role      = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

/*
# IAM Role for ECS Service
resource "aws_iam_role" "ecs_service_role" {
  name = "ecs_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = [
            "ecs.amazonaws.com",
            "codedeploy.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Policy Attachment for ECS Service Role - ECS
resource "aws_iam_role_policy_attachment" "ecs_service_policy_attachment" {
  role      = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "ecs_service_policy"
  role = aws_iam_role.ecs_service_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:ListTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListServices",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancers"
        ],
        Resource = "*"
      }
    ]
  })
}

*/

# Custom IAM Policy for ECS Task Secrets
resource "aws_iam_policy" "ecs_task_secrets_policy" {
  name        = "ecs_task_secrets_policy"
  description = "Policy to allow ECS tasks to access Secrets Manager secrets"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = "*"
      }
    ]
  })
}

# Policy Attachment for ECS Task Secrets Policy
resource "aws_iam_role_policy_attachment" "ecs_task_secrets_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn  = aws_iam_policy.ecs_task_secrets_policy.arn
}


