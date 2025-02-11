# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Create pipelines for deploying applications in AWS Fargate
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 

provider "aws" {
  region = local.aws_region
}

locals {
  aws_region        = "ca-central-1"
  build_bucket_name = "name_of_your_build_bucket"
}

resource "aws_codepipeline" "pipeline" {
  for_each = var.pipelines

  name     = "deployment-master-${var.cluster_name}-${each.key}"
  role_arn = aws_iam_role.codepipeline.arn

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        PollForSourceChanges = "false"
        RepositoryName       = "deployment"
        BranchName           = "master"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ClusterName = var.cluster_name
        ServiceName = each.key
        FileName    = "${var.cluster_name}/${each.key}/revision.json"
      }
    }
  }

  artifact_store {
    type     = "S3"
    location = local.build_bucket_name
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE IAM ROLE AND POLICY FOR CODEPIPELINE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "codepipeline" {
  name               = "${var.cluster_name}-deployment-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_role_policy.json
}

data "aws_iam_policy_document" "codepipeline_role_policy" {

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy" "codepipeline_iam_role_policy" {
  role   = aws_iam_role.codepipeline.name
  policy = data.aws_iam_policy_document.codepipeline_policy_document.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "codepipeline_policy_document" {

  //for getting image definitions file from CodeCommit
  statement {
    effect = "Allow"

    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:CancelUploadArchive"
    ]

    resources = [
      "arn:aws:codecommit:${local.aws_region}:${data.aws_caller_identity.current.account_id}:deployment"
    ]
  }

  //for uploading to S3 and downloading from S3 bucket for deployment
  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${local.build_bucket_name}/*"
    ]
  }

  //for deploying to ECS
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["*"]

    condition {
      test     = "StringEqualsIfExists"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  //for deploying to ECS
  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeServices",
      "ecs:UpdateService",
      "ecs:RegisterTaskDefinition"
    ]

    resources = ["*"]
  }
}
