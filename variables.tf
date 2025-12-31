
variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "pipeline_name" {
  type        = string
  description = "CodePipeline name"
  default     = "github-codepipeline"
}

variable "project_name" {
  type        = string
  description = "CodeBuild project name"
  default     = "github-codebuild-project"
}

variable "artifact_bucket" {
  type        = string
  description = "S3 bucket for CodePipeline artifacts (must have versioning enabled)"
}

# GitHub (CodeStar Connections)
variable "github_owner" {
  type        = string
  description = "GitHub organization or user"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_branch" {
  type        = string
  description = "Branch to build"
  default     = "dev"
}
