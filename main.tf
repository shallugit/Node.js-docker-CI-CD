resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-1a"
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-1b"
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "instance" {
  name        = "allow_http_ssh"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "main"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    Name = "MainSubnetGroup"
  }
}

resource "aws_security_group" "rds" {
  name        = "rds_sg"
  description = "Allow MySQL traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0.32"
  instance_class       = "db.t3.micro"
  db_name              = "mydatabase"
  username             = "admin"
  password             = "yourpassword"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  tags = {
    Name = "MyDatabase"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-03ed1381c73a5660e" # Amazon Linux 2 AMI
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user
              chkconfig docker on
              
              # Install Node.js
              curl -sL https://rpm.nodesource.com/setup_14.x | bash -
              yum install -y nodejs
              
              # Create the Node.js application
              mkdir /home/ec2-user/app
              cd /home/ec2-user/app
              
              cat << 'EOL' > app.js
              const express = require('express');
              const mysql = require('mysql');
              const app = express();
              const port = 8080;

              const db = mysql.createConnection({
                host: '${aws_db_instance.default.endpoint}',
                user: 'admin',
                password: 'yourpassword',
                database: 'mydatabase'
              });

              db.connect(err => {
                if (err) {
                  console.error('Database connection failed:', err.stack);
                  return;
                }
                console.log('Connected to database.');
              });

              app.get('/', (req, res) => {
                res.send('Hello World!');
              });

              app.listen(port, () => {
                console.log(App listening at http://localhost:$${port});
              });
              EOL

              cat << 'EOL' > package.json
              {
                "name": "node-docker",
                "version": "1.0.0",
                "description": "A simple Node.js app running in Docker",
                "main": "app.js",
                "scripts": {
                  "start": "node app.js"
                },
                "dependencies": {
                  "express": "^4.17.1",
                  "mysql": "^2.18.1"
                }
              }
              EOL

              npm install

              # Create Dockerfile
              cat << 'EOL' > Dockerfile
              FROM node:14

              WORKDIR /usr/src/app

              COPY package*.json ./

              RUN npm install

              COPY . .

              EXPOSE 8080

              CMD ["npm", "start"]
              EOL

              # Build and run Docker container
              docker build -t my-node-app .
              docker run -d -p 80:8080 my-node-app
              EOF

  tags = {
    Name = "NodeApp"
  }

  # Ensure SSH access for debugging
  key_name = "Terraform"
  vpc_security_group_ids = [aws_security_group.instance.id]
}

output "rds_endpoint" {
  value = aws_db_instance.default.endpoint
}
