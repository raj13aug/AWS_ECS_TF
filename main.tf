# call the ECR module
module "ecr" {
  source = "./ecr"
}

# call the ECS module
module "ecs" {
  source = "./ecs"
}

# call the CodePipeline module
module "codepipeline" {
  source = "./codepipeline"
}
