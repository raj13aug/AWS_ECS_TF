# call the CodePipeline module
module "codepipeline" {
  source = "./codepipeline"
}


# # call the ECS module
module "ecs" {
  source     = "./ecs"
  depends_on = [module.codepipeline]
}