
output "pipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.pipeline.name
}

output "codebuild_project_name" {
  description = "CodeBuild project name"
  value       = aws_codebuild_project.project.name
}

output "github_connection_arn" {
  description = "CodeStar Connections ARN for GitHub"
  value       = aws_codestarconnections_connection.github.arn
}
