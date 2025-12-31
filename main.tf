
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ------------------------------
# S3: Artifact store (versioning)
# ------------------------------
resource "aws_s3_bucket_versioning" "artifact_versioning" {
  bucket = var.artifact_bucket
  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------
# IAM: CodeBuild service role + policy
# -----------------------------------
resource "aws_iam_role" "codebuild_role" {
  name               = "${var.project_name}-ServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codebuild.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "${var.project_name}-InlinePolicy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Pipeline-managed artifacts: CodeBuild interacts with temp S3 locations provided by CodePipeline
      {
        Sid    = "S3ArtifactsReadWrite",
        Effect = "Allow",
        Action = [
          "s3:GetObject", "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.artifact_bucket}",
          "arn:aws:s3:::${var.artifact_bucket}/*"
        ]
      },
      # CloudWatch Logs for build logs
      {
        Sid    = "CloudWatchLogs",
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# -----------------------
# CodeBuild Project
# -----------------------
resource "aws_codebuild_project" "project" {
  name         = var.project_name
  description  = "Build project for GitHub source via CodePipeline"
  service_role = aws_iam_role.codebuild_role.arn
  build_timeout = 20

  artifacts {
    type      = "CODEPIPELINE"   # Pipeline-managed artifacts
    packaging = "ZIP"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"  # Amazon Linux 2023 standard image
    type         = "LINUX_CONTAINER"
  }

#  source {
#    type      = "CODEPIPELINE"   # Source provided by CodePipeline
#    buildspec = <sts:AssumeRole, type = "KMS" }
#  }
source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOT
      version: 0.2
      phases:
        build:
          commands:
            - echo "Build started"
            - mkdir -p dist
            - cp -r * dist/ || true
            - zip -r build_output.zip dist
      artifacts:
        files:
          - build_output.zip
    EOT
  }

  logs_config {
    cloudwatch_logs { status = "ENABLED" }
  }
}

  # --- SOURCE (GitHub via CodeStar Connections) ---
  stage {
    name = "Source"

    action {
      name             = "GitHubSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]
      run_order        = 1

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"  # org/repo
        BranchName       = var.github_branch
        DetectChanges    = "true"   # enables webhook integration for pushes
      }
    }
  }

  # --- BUILD (CodeBuild) ---
  stage {
    name = "Build"

    action {
      name             = "CodeBuild"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = aws_codebuild_project.project.name
      }
    }
  }

  depends_on = [
    aws_iam_role_policy.codepipeline_policy,
    aws_s3_bucket_versioning.artifact_versioning
  ]
}
