resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*",
          "codecommit:*",
          "codebuild:*",
          "ecs:*",
          "iam:PassRole"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "nodeapp-codepipeline-bucket"
}

resource "aws_codecommit_repository" "nodeapp_repo" {
  repository_name = "nodeapp-repo"
}

resource "aws_codebuild_project" "nodeapp_build" {
  name          = "nodeapp-build"
  service_role  = aws_iam_role.codepipeline_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }
  source {
    type     = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 14
    commands:
      - echo Installing dependencies...
      - npm install
  build:
    commands:
      - echo Build started on `date`
      - npm run build
artifacts:
  files:
    - '**/*'
EOF
  }
}

resource "aws_ecs_cluster" "nodeapp_cluster" {
  name = "nodeapp-cluster"
}

resource "aws_ecs_service" "nodeapp_service" {
  name            = "nodeapp-service"
  cluster         = aws_ecs_cluster.nodeapp_cluster.id
  task_definition = aws_ecs_task_definition.nodeapp_task.arn
  desired_count   = 1
}

resource "aws_ecs_task_definition" "nodeapp_task" {
  family                   = "nodeapp-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.codepipeline_role.arn
  container_definitions = jsonencode([{
    name      = "nodeapp"
    image     = "node:14"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"        = "/ecs/nodeapp"
        "awslogs-region"       = "us-west-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_codepipeline" "nodeapp_pipeline" {
  name     = "nodeapp-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

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
        RepositoryName = aws_codecommit_repository.nodeapp_repo.name
        BranchName     = "main"
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
        ProjectName = aws_codebuild_project.nodeapp_build.name
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
        ClusterName = aws_ecs_cluster.nodeapp_cluster.name
        ServiceName = aws_ecs_service.nodeapp_service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
