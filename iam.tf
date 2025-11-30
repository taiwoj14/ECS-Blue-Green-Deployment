/*
data "aws_iam_policy_document" "ecs_service_role_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
    effect = "Allow"
  }
}


resource "aws_iam_role" "ecs_service_role" {
  name               = "ecs_service_role_e"
  assume_role_policy = data.aws_iam_policy_document.ecs_service_role_trust.json
}


data "aws_iam_policy_document" "ecs_service_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstances",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:ListServices",
      "ecs:UpdateService",
      "iam:PassRole"
    ]
    resources = ["*"]
  }
}



resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs_service_role_policy"
  role   = aws_iam_role.ecs_service_role.id
  policy = data.aws_iam_policy_document.ecs_service_role_policy.json
}
*/

resource "aws_iam_role" "ecs_service_role_app" {
  name = "ecs_service_role_app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = [
            "ecs.amazonaws.com",
            "codedeploy.amazonaws.com",
            "ecs-tasks.amazonaws.com"
          ]
        }
      }
    ]
  })
}

# Policy Attachment for ECS Service Role - AmazonEC2ContainerServiceRole
resource "aws_iam_role_policy_attachment" "ecs_service_policy_attachment" {
  role      = aws_iam_role.ecs_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

# Custom Inline Policy for ECS Service Role
resource "aws_iam_role_policy" "ecs_service_policy" {
  name = "ecs_service_policy"
  role = aws_iam_role.ecs_service_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstances",
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:ListServices",
          "ecs:UpdateService",
          "iam:PassRole",
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


resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/ecs/appy"
  retention_in_days = 7
}

resource "aws_iam_policy" "ecs_task_logging_policy" {
  name = "ecs_task_logging_policy_e"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:*:*:log-group:/ecs/app:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_logging_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_logging_policy.arn
}

