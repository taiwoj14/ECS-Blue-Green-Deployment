data "aws_iam_policy_document" "codedeploy_assume_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codedeploy_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sns:Publish",
      "s3:GetObjectVersion",
      "s3:GetObject",
      "lambda:InvokeFunction",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeListeners",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeServices",
      "ecs:DeleteTaskSet",
      "ecs:CreateTaskSet",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:Get*",
      "codedeploy:CreateDeployment",
      "cloudwatch:DescribeAlarms"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "s3:Get*"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Encrypt",
      "kms:DescribeKey",
      "kms:Decrypt"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["iam:PassRole"]
    condition {
      test     = "StringLike"
      variable = "iam:PassedToService"
      values  = ["ecs-tasks.amazonaws.com"]
    }
    resources = ["*"]
  }
}


resource "aws_iam_role" "codedeploy_role" {
  name               = "abgcodepb_codedeploy_role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_assume_policy.json
}

resource "aws_iam_role_policy" "codedeploy_policy" {
  name   = "bgcodedp_codedeploy_policy"
  role   = aws_iam_role.codedeploy_role.id
  policy = data.aws_iam_policy_document.codedeploy_role_policy.json
}
