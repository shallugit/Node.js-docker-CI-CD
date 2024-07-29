# Node.js-docker-CI-CD

https://app.eraser.io/workspace/szumeIMvTtlvs6YSw1nH?origin=share - Workflow Diagram 

Overview:

This project involves creating a Node.js application that connects to an AWS RDS MySQL database, all provisioned using Terraform. The application is containerized using Docker, and the infrastructure is managed via a CI/CD pipeline implemented with AWS CodePipeline, CodeCommit and CodeBuild.

Architecture:

The architecture of the project includes the following components:

•	VPC: A Virtual Private Cloud to host the AWS resources.

•	Subnets: Two subnets in different availability zones.

•	Internet Gateway: To allow internet access to the instances.

•	Route Tables: To route traffic from the instances to the internet.

•	Security Groups: To allow specific traffic (SSH, HTTP, MySQL) to the instances and RDS.

•	EC2 Instances: Running Docker and hosting the Node.js application.

•	RDS Instance: A MySQL database instance.

•	CI/CD Pipeline: AWS CodePipeline for continuous integration and delivery.

Project Structure:

•	main.tf: Terraform configuration for provisioning the VPC, subnets, route tables, security groups, EC2 instances, and RDS instance.

•	codepipeline.tf: Terraform configuration for setting up the CI/CD pipeline.

•	Dockerfile: Instructions for building the Docker image for the Node.js application.

•	app.js: The Node.js application code.

•	package.json: The Node.js application dependencies.

Prerequisites:

•	Terraform installed on your local machine.

•	AWS CLI configured with the necessary permissions.

•	A key pair for SSH access to the EC2 instances.

•	Docker installed on your local machine (for building and testing the Docker image locally).

Challenges Faced:

•	Terraform Configuration: Everytime when you change anything in the code, the entire structure of terraform gets destroy and again should build it.

•	Docker Configuration: Properly setting up the Dockerfile to containerize the Node.js applicatio.

•	CI/CD Pipeline: Configuring the pipeline to work seamlessly with the infrastructure and application code.

