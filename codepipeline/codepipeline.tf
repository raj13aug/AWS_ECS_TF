
data "aws_ecr_repository" "existing_repo" {
  name = "ecs-app-repo"
}

# data "aws_ecs_cluster" "ecs" {
#   cluster_name = "my-demo-cluster"
# }

# data "aws_ecs_service" "ecs" {
#   cluster_arn  = data.aws_ecs_cluster.ecs.arn
#   service_name = "my-service"
# }

resource "aws_iam_role" "codepipeline_role" {
  name = "codepipelinerole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    tag-key = "codepipelinerole"
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  name        = "codepipelinepolicy"
  description = "My test policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
          "s3:*",
          "ecr:*",
          "ecs:*",
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "codepipeline_policy_attachement" {
  name       = "codepipelinepolicyattachement"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.codepipeline_policy.arn
}

resource "aws_codebuild_project" "build_project" {
  name         = "ECSBuildProject"
  service_role = aws_iam_role.codepipeline_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "REPOSITORY_URI"
      value = data.aws_ecr_repository.existing_repo.repository_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("codepipeline/buildspec.yml")

  }

  tags = {
    Environment = "ECSBuildProject"
  }
}

resource "aws_codestarconnections_connection" "github" {
  name          = "my-github-connection"
  provider_type = "GitHub"
}

resource "aws_s3_bucket" "pipeline_bucket" {
  bucket = "ecs-pipeline-artifacts-785"
  tags   = { name = "ECS Pipeline Bucket" }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "ECSpipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = aws_codestarconnections_connection.github.arn
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = "raj13aug"
        Repo       = "https://github.com/raj13aug/ecs_code_pipeline.git"
        BranchName = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.build_project.name
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
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ClusterName = "my-demo-cluster" # data.aws_ecs_cluster.ecs.cluster_name #aws_ecs_cluster.ECS.name    
        ServiceName = "my-service"      # data.aws_ecs_service.ecs.service_name #aws_ecs_service.ECS-Service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
