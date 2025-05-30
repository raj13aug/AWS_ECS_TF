# random ID generate

resource "random_id" "suffix" {
  byte_length = 4
}

# Store code pipeline artifacts
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "pipeline-artifacts-nataraj-${random_id.suffix.hex}"
  force_destroy = true
}

# ECR repo
resource "aws_ecr_repository" "my_repo" {
  name         = "ecs-app-repo"
  force_delete = true
}

# IAM policy
resource "aws_iam_policy" "codepipeline_s3_policy" {
  name        = "CodePipelineS3Policy"
  description = "CodePipeline acess to s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::pipeline-artifacts-nataraj-${random_id.suffix.hex}",
          "arn:aws:s3:::pipeline-artifacts-nataraj-${random_id.suffix.hex}/*"
        ]
      }
    ]
  })
}

#Attach s3 policy to codepiple role

resource "aws_iam_role_policy_attachment" "attach_s3_policy_to_pipeline_role" {
  policy_arn = aws_iam_policy.codepipeline_s3_policy.arn
  role       = aws_iam_role.codepipeline_role.name
}

#IAM policy for codepipeline for ecs , ecr and s3
resource "aws_iam_policy" "codepipeline_codebuild_permissions" {
  name        = "CodePipelineCodeBuildPermissions"
  description = "CodePipelineCodeBuildPermissions CodeBuild"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:StartBuild",
        "codebuild:BatchGetBuilds",
        "ec2:Describe*",
        "s3:*",
        "ecr:*",
        "ecs:*",
        "iam:PassRole",
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "arn:aws:codebuild:us-east-1:932999788441:project/Auto-ECS-Test"
    }
  ]
}
EOF
}

#Attach policy to codepipeline role
resource "aws_iam_role_policy_attachment" "codepipeline_codebuild_attach" {
  policy_arn = aws_iam_policy.codepipeline_codebuild_permissions.arn
  role       = aws_iam_role.codepipeline_role.name
}

# IAM policy for cloudwatch
resource "aws_iam_policy" "codebuild_cloudwatch_permissions" {
  name        = "CodeBuildCloudWatchPermissions"
  description = "logs CloudWatch"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:932999788441:log-group:/aws/codebuild/*"
    }
  ]
}
EOF
}

#Attach the cloudwatch policy to codebuild
resource "aws_iam_role_policy_attachment" "codebuild_cloudwatch_attach" {
  policy_arn = aws_iam_policy.codebuild_cloudwatch_permissions.arn
  role       = aws_iam_role.codebuild_role.name
}

# create the assume role
resource "aws_iam_role" "codebuild_role" {
  name               = "CodeBuildRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}
#Attach the cloudwatAmazonS3FullAccess  policy to codebuild
resource "aws_iam_policy_attachment" "codebuild_ecs_acess" {
  name       = "codebuild-attach"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess" #AmazonS3FullAccess
}

#Attach the ECR  policy to codebuild
resource "aws_iam_policy_attachment" "codebuild_permissions" {
  name       = "codebuild-attach"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
#Attach the S3  policy to codebuild
resource "aws_iam_policy_attachment" "codebuild_s3_access" {
  name       = "codebuild-attach"
  roles      = [aws_iam_role.codebuild_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}


# create the code build project
resource "aws_codebuild_project" "auto_test" {
  name          = "Auto-ECS-Test"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "10"

  source {
    type     = "GITHUB"
    location = "https://github.com/raj13aug/ecs_code_pipeline.git"

    buildspec = <<EOF
    version: 0.2
    env:
      variables:
        AWS_DEFAULT_REGION: "us-east-1"
        REPOSITORY_URI: "932999788441.dkr.ecr.us-east-1.amazonaws.com/ecs-app-repo"

    phases:
      pre_build:
        commands:
          - echo Logging in to Amazon ECR...
          - aws --version
          - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 932999788441.dkr.ecr.us-east-1.amazonaws.com/ecs-app-repo
          - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
          - IMAGE_TAG=$${COMMIT_HASH:=latest}          
      build:
        commands:
          - echo Build started on `date`
          - echo Building the Docker image...
          - docker build -t $REPOSITORY_URI:latest .
          - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
      post_build:
        commands:
          - echo Build completed on `date`
          - echo Pushing the Docker images...
          - docker push $REPOSITORY_URI:$IMAGE_TAG
          - echo Writing image definitions file...
          - printf '[{"name":"container","imageUri":"%s"}]'  $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
    artifacts:
        files: imagedefinitions.json
      EOF
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }

  artifacts {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifacts.bucket
  }
}

# create the assume role
resource "aws_iam_role" "codepipeline_role" {
  name               = "CodePipelineRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

#create ecs policy to policy
resource "aws_iam_policy" "codepipeline_ecs_permission" {
  name        = "CodepipelineECSPermissions"
  description = "CodepipelineECSPermissions"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

#Attach the codepipeline policy to codebuild

resource "aws_iam_policy_attachment" "codepipeline_ecs" {
  name       = "codepipeline-attach"
  roles      = [aws_iam_role.codepipeline_role.name]
  policy_arn = aws_iam_policy.codepipeline_ecs_permission.arn
}

# Defined the code pipeline with stages

resource "aws_codepipeline" "automation_pipeline" {
  name     = "Auto-ECS-Test-Pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "raj13aug"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["SourceOutput"]
      configuration = {
        Owner      = "raj13aug"
        Repo       = "ecs_code_pipeline"
        Branch     = "main"
        OAuthToken = var.github_token
      }
    }
  }


  stage {
    name = "Build"
    action {
      name             = "Build-Stage"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.auto_test.name
      }
    }
  }

  stage {
    name = "Approval"
    action {
      name      = "ManualApproval"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 1
      configuration = {
        CustomData = "Please approve deployment to ECS"
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
      input_artifacts = ["BuildOutput"]
      version         = "1"

      configuration = {
        ClusterName = "my-demo-cluster" # data.aws_ecs_cluster.ecs.cluster_name #aws_ecs_cluster.ECS.name    
        ServiceName = "my-service"      # data.aws_ecs_service.ecs.service_name #aws_ecs_service.ECS-Service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
