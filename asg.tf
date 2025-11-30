# Launch Template
# Data source to fetch the latest ECS-Optimized Amazon Linux 2 AMI
/*
data "aws_ami" "ecs_amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-*-x86_64-gp2"] # Adjust the filter based on the latest AMI naming convention
  }
}
*/

resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template-"
  image_id      = "ami-0fa3fe0fa7920f68e"
  instance_type = "t3.micro"

  key_name = "MyAccessKeyPair" # Replace with your key pair name
  
   user_data = base64encode(<<-EOT
    #!/bin/bash
    echo ECS_CLUSTER=main-cluster >> /etc/ecs/ecs.config
  EOT
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.app_sg.id]


  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "app-instance"
    }
  }
}


# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  vpc_zone_identifier = [aws_subnet.private_subnet1.id, aws_subnet.private_subnet2.id]

#  target_group_arns = [aws_lb_target_group.app_tg.arn]

  min_size           = 3
  max_size           = 8
  desired_capacity   = 3
  
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}




# Define IAM Role and Instance Profile for EC2 Instances
resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2-instance-role_e"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_instance_policy_attachment" {
  role      = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role      = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}
