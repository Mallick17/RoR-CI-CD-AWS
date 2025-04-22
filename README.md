# Real Time Ruby On Rails Chat App, Creating Docker Image with AWS CodeBuild.

## 🗂 Folder Structure (Example)
```
chat-app/
├── Dockerfile
├── buildspec.yml
├── appspec.yml
└── scripts/
    ├── before_install.sh
    ├── after_install.sh
    ├── start.sh
    ├── docker-compose.yml
    └── stop.sh
```

## ⚙️ Permissions
Make sure to make the scripts folder executable:
```bash
chmod +x scripts/*.sh
```
---

## Create `Dockerfile` in the root path of Repo
The Dockerfile specifies the steps to create the application’s Docker image. A typical Dockerfile for a RoR application might look like this which is provided below:

<details>
  <summary>Click to view Dockerfile</summary>

```dockerfile
# Dockerfile

FROM ruby:3.2.2
## This pulls the official Ruby 3.2.2 image from Docker Hub (Docker Hub),
## which includes Ruby and a Debian-based Linux environment.
## This is the foundation for the container, ensuring compatibility with the RoR applica                                                                                                tion.

# Set working directory
WORKDIR /app

## Sets the working directory inside the container to /app,
## where all subsequent commands will execute.
## This is where the application code will reside,
## following best practices for organization.

# Install packages
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs curl redis

## Updates the package list quietly (-qq) and installs essential packages:
### build-essential: Provides compilers and libraries (e.g., gcc, make) needed for building software.
### libpq-dev: Development files for PostgreSQL, required for the pg gem used in Rails for database connectivity.
### nodejs: JavaScript runtime, necessary for asset compilation (e.g., Webpacker or Sprockets).
### curl: A tool for transferring data, used here for installing additional tools like Yarn.
## redis: Installs the Redis server, likely used for caching or real-time features like ActionCable.
## This step ensures the container has all system-level dependencies for the RoR app.

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && apt-get update && apt-get install -y yarn

## Installs Yarn, a package manager for JavaScript, which is often used in Rails for managing frontend dependencies:
### First, adds the Yarn GPG key for secure package verification.
### Adds the Yarn repository to the sources list.
### Updates the package list and installs Yarn.
## This is crucial for applications using JavaScript frameworks or asset pipelines.

# Install bundler
RUN gem install bundler

## Installs Bundler, the Ruby dependency manager,
## which reads the Gemfile to install gems.
## This ensures the RoR application has all required Ruby libraries.

# Copy Gemfiles and install dependencies
COPY Gemfile* ./
RUN bundle install

## Copies the Gemfile and Gemfile.lock to the container,
## then runs bundle install to install the gems specified.
## This step is done early to leverage Docker layer caching,
## improving build times if the Gemfile doesn't change.

# Copy rest of the application
COPY . .
## Copies the entire application code from the host to the container's /app directory.
## This includes all source files, configurations, and assets.

# Ensure tmp directories exist
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log
## Creates directories for temporary files, cache, sockets, and logs.
## The -p flag ensures parent directories are created if they don't exist,
## preventing errors. These directories are standard for Rails applications,
## used by Puma and other processes.


# Precompile assets (optional for production)
RUN bundle exec rake assets:precompile

## Precompiles assets (CSS, JavaScript) for production using the rake
## assets:precompile task. This step is optional but recommended for production
## to improve performance by serving precompiled assets, reducing server load.

# Expose the app port
EXPOSE 3000

## Informs Docker that the container listens on port 3000 at runtime.
## This is the default port for Rails applications using Puma,
## making it accessible externally when mapped.

# Start the app with Puma
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

## Specifies the default command to run when the container starts.
## It uses Bundler to execute Puma, the web server for Rails,
## with the configuration file config/puma.rb.
## This starts the application, listening on port 3000.
```

</details>

---

## Create `buildspec.yml` in the root path of Repo

<details>
  <summary>Click to view buildspec.yml</summary>

```yml
version: 0.2

env:
  variables:
    IMAGE_NAME: "chat-app"
    IMAGE_TAG: "latest"
  secrets-manager:
    RAILS_ENV: chat-app-secrets:RAILS_ENV
    DB_USER: chat-app-secrets:DB_USER
    DB_PASSWORD: chat-app-secrets:DB_PASSWORD
    DB_HOST: chat-app-secrets:DB_HOST
    DB_PORT: chat-app-secrets:DB_PORT
    DB_NAME: chat-app-secrets:DB_NAME
    REDIS_URL: chat-app-secrets:REDIS_URL
    RAILS_MASTER_KEY: chat-app-secrets:RAILS_MASTER_KEY
    SECRET_KEY_BASE: chat-app-secrets:SECRET_KEY_BASE

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPO_URI
      - echo "RAILS_ENV=$RAILS_ENV" > .env
      - echo "DB_USER=$DB_USER" >> .env
      - echo "DB_PASSWORD=$DB_PASSWORD" >> .env
      - echo "DB_HOST=$DB_HOST" >> .env
      - echo "DB_PORT=$DB_PORT" >> .env
      - echo "DB_NAME=$DB_NAME" >> .env
      - echo "REDIS_URL=$REDIS_URL" >> .env
      - echo "RAILS_MASTER_KEY=$RAILS_MASTER_KEY" >> .env
      - echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> .env

  build:
    commands:
      - echo Building the Docker image...
      - docker build -t $IMAGE_NAME:$IMAGE_TAG .
      - docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_REPO_URI:$IMAGE_TAG

  post_build:
    commands:
      - echo Pushing Docker image to ECR...
      - docker push $ECR_REPO_URI:$IMAGE_TAG
      - echo Build completed successfully.

artifacts:
  files:
    - appspec.yml
    - scripts/*
```

</details>

---

## Create `appspec.yml` in the root path of Repo

<details>
  <summary>Click to view appspec.yml</summary>

```yml
version: 0.0
os: linux
files:
  - source: .
    destination: /home/ubuntu/chat-app

hooks:
  ApplicationStop:
    - location: scripts/stop.sh
      timeout: 60
  BeforeInstall:
    - location: scripts/before_install.sh
      timeout: 60
  AfterInstall:
    - location: scripts/after_install.sh
      timeout: 60
  ApplicationStart:
    - location: scripts/start.sh
      timeout: 60
```

</details>

---

## Create `docker-compose.yml` in the scripts folder in the repo

<details>
  <summary>Click to view docker-compose.yml</summary>

```yml
version: '3.8'

services:
  web:
    build: .
    image: 339713104321.dkr.ecr.ap-south-1.amazonaws.com/chat-app:latest
    command: bash -c "rm -f tmp/pids/server.pid && bundle exec puma -C config/puma.rb"
    ports:
      - "3000:3000"
    environment:
      RAILS_ENV: production
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
      REDIS_URL: redis://redis:6379/0
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}         # ✅ Added
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}       # ✅ Added
    depends_on:
      - redis
    restart: always

  redis:
    image: redis:7
    container_name: redis
    restart: always
    ports:
      - "6379:6379"

```
</details>
    
---

### We're deploying a **Dockerized Ruby on Rails app** on **Ubuntu EC2 instances** using **AWS CodeDeploy**, your scripts (`start.sh`, `stop.sh`, `before_install.sh`, `after_install.sh`) will live inside a `scripts/` directory at the **root of your repository**.

## Create `start.sh` in the scripts folder in the repo

<details>
  <summary>Click to view start.sh</summary>

```sh
#!/bin/bash
set -euo pipefail

echo "🚀 Running start.sh..."

APP_DIR="/home/ubuntu/chat-app"
COMPOSE_FILE="$APP_DIR/scripts/docker-compose.yml"
ECR_IMAGE="339713104321.dkr.ecr.ap-south-1.amazonaws.com/chat-app:latest"
SECRET_ARN="arn:aws:secretsmanager:ap-south-1:339713104321:secret:chat-app-secrets-rXZYzv"
REGION="ap-south-1"

# Binary paths
AWS_CLI="/usr/bin/aws"
DOCKER="/usr/bin/docker"
DOCKER_COMPOSE="/usr/local/bin/docker-compose"

# Ensure required tools exist
for cmd in $AWS_CLI $DOCKER $DOCKER_COMPOSE jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Required command '$cmd' not found. Exiting."
    exit 1
  fi
done

# Navigate to app directory
cd "$APP_DIR" || { echo "❌ Directory $APP_DIR not found"; exit 1; }

# Authenticate Docker to ECR
echo "🔐 Logging in to Amazon ECR..."
$AWS_CLI ecr get-login-password --region "$REGION" | $DOCKER login --username AWS --password-stdin "$ECR_IMAGE" || {
  echo "❌ ECR login failed"; exit 1;
}

# Pull the latest image
echo "📦 Pulling latest image from ECR..."
$DOCKER pull "$ECR_IMAGE"

# Shut down existing containers (non-fatal)
echo "🛑 Stopping existing containers (if any)..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" down || true

# Fetch secrets from Secrets Manager
echo "🔐 Fetching secrets from AWS Secrets Manager..."
SECRET_JSON=$($AWS_CLI secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --region "$REGION" \
  --query SecretString \
  --output text)

# Export environment variables
export DB_USER=$(echo "$SECRET_JSON" | jq -r '.DB_USER')
export DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.DB_PASSWORD')
export DB_HOST=$(echo "$SECRET_JSON" | jq -r '.DB_HOST')
export DB_PORT=$(echo "$SECRET_JSON" | jq -r '.DB_PORT')
export DB_NAME=$(echo "$SECRET_JSON" | jq -r '.DB_NAME')
export SECRET_KEY_BASE=$(echo "$SECRET_JSON" | jq -r '.SECRET_KEY_BASE')
export RAILS_MASTER_KEY=$(echo "$SECRET_JSON" | jq -r '.RAILS_MASTER_KEY')  # 👈 NEW

echo "Secrets loaded and exported."

# Start containers
echo "🚀 Starting containers using Docker Compose..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d || {
  echo "❌ Failed to start containers"; exit 1;
}

echo "✅ Deployment completed successfully."
```

</details>

---

## Create `stop.sh` in the scripts folder in the repo

<details>
  <summary>Click to view stop.sh</summary>

```sh
#!/bin/bash
echo "Running stop.sh..."

cd /home/ubuntu/chat-app

# Stop and remove containers
docker-compose down || true
```

</details>

---

## Create `before_install.sh` in the scripts folder in the repo

<details>
  <summary>Click to view before_install.sh</summary>

```sh
#!/bin/bash
echo "Running before_install.sh..."

# Stop old containers
docker-compose -f /home/ubuntu/chat-app/docker-compose.yml down || true

# Remove old images (optional cleanup)
docker system prune -af || true
```
</details>

---

## Create `after_install.sh` in the scripts folder in the repo

<details>
  <summary>Click to view after_install.sh</summary>

```yml
#!/bin/bash
echo "Running after_install.sh..."

# Change ownership (optional, if files are owned by root)
chown -R ubuntu:ubuntu /home/ubuntu/chat-app
```

</details>

---




## **Step-by-Step guide** on how to store your `.env` secrets in **AWS Secrets Manager using the Console UI**

<details>
  <summary>Click to view Step-by-Step: Store Rails `.env` Secrets in AWS Secrets Manager (Console)</summary>

### 🪪 Step-by-Step: Store Rails `.env` Secrets in AWS Secrets Manager (Console)

### 🔹 **Step 1: Choose Secret Type**

1. Go to **AWS Secrets Manager > Store a new secret**
2. Under **Secret type**, select:
   - ✅ **Other type of secret**
   - (This is for API keys, app secrets, or in your case, environment variables)

---

### 🔹 **Step 2: Enter Key/Value Pairs**

Now, enter each key and its value from your `.env` file:

| Key                | Value                                                              |
|--------------------|--------------------------------------------------------------------|
| `RAILS_ENV`        | `production`                                                      |
| `DB_USER`          | `myuser`                                                          |
| `DB_PASSWORD`      | `mypassword`                                                      |
| `DB_HOST`          | `chat-app.c342ea4cs6ny.ap-south-1.rds.amazonaws.com`              |
| `DB_PORT`          | `5432`                                                            |
| `DB_NAME`          | `chat-app`                                                        |
| `REDIS_URL`        | `redis://redis:6379/0`                                            |
| `RAILS_MASTER_KEY` | `c3ca922688d4bf22ac7fe38430dd8849`                                |
| `SECRET_KEY_BASE`  | `600f21de02355f788c759ff862a2cb22ba84ccbf072487992f4...` *(etc.)* |

➡️ To do this:
- Click **+ Add row** for each new key.
- Paste in each key on the left and value on the right.

---

### 🔹 **Step 3: Encryption Key**

- Leave this as default: `aws/secretsmanager`

AWS will handle encryption with its default KMS key.

---

### 🔹 **Step 4: Click “Next”**

Once all keys are added:
- Click the **orange “Next”** button at the bottom-right.

---

### 🔹 **Step 5: Secret Name and Description**

1. Set the name to something like:
   ```
   chat-app-secrets
   ```
2. Optionally, add a helpful description, e.g.:
   ```
   Environment variables for Ruby on Rails chat app
   ```

---

### 🔹 **Step 6: Leave Rotation Off**

- Click **Next** on the rotation screen (optional).
- You don't need rotation for this kind of secret.

---

### 🔹 **Step 7: Review and Store**

1. Review your key-value pairs and secret name.
2. Click **Store**.
  
</details>

---

## Step-by-Step: Create IAM Role for CodeBuild (with Required Policies)
### 1. **Go to IAM > Roles > Create Role**
- **Trusted Entity**: AWS service
- **Use case**: Choose **CodeBuild**
- Click **Next**

### 2. **Attach Policies**

<details>
  <summary>Click to view all the 10 Policies Attached to the Role</summary>


- **I. `AmazonEC2ContainerRegistryPowerUser`**
  - Provides full access to Amazon EC2 Container Registry repositories, but does not allow repository deletion or policy changes.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:GetLifecyclePolicy",
                "ecr:GetLifecyclePolicyPreview",
                "ecr:ListTagsForResource",
                "ecr:DescribeImageScanFindings",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload",
                "ecr:PutImage"
            ],
            "Resource": "*"
        }
    ]
}
```
  
</details>
  
- **II. `AmazonECS_FullAccess`**
  - Provides administrative access to Amazon ECS resources and enables ECS features through access to other AWS service resources, including VPCs, Auto Scaling groups, and CloudFormation stacks.
  - AWS managed
  
<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECSIntegrationsManagementPolicy",
            "Effect": "Allow",
            "Action": [
                "application-autoscaling:DeleteScalingPolicy",
                "application-autoscaling:DeregisterScalableTarget",
                "application-autoscaling:DescribeScalableTargets",
                "application-autoscaling:DescribeScalingActivities",
                "application-autoscaling:DescribeScalingPolicies",
                "application-autoscaling:PutScalingPolicy",
                "application-autoscaling:RegisterScalableTarget",
                "appmesh:DescribeVirtualGateway",
                "appmesh:DescribeVirtualNode",
                "appmesh:ListMeshes",
                "appmesh:ListVirtualGateways",
                "appmesh:ListVirtualNodes",
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:CreateLaunchConfiguration",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:DeleteLaunchConfiguration",
                "autoscaling:Describe*",
                "autoscaling:UpdateAutoScalingGroup",
                "cloudformation:CreateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStack*",
                "cloudformation:UpdateStack",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:PutMetricAlarm",
                "codedeploy:BatchGetApplicationRevisions",
                "codedeploy:BatchGetApplications",
                "codedeploy:BatchGetDeploymentGroups",
                "codedeploy:BatchGetDeployments",
                "codedeploy:ContinueDeployment",
                "codedeploy:CreateApplication",
                "codedeploy:CreateDeployment",
                "codedeploy:CreateDeploymentGroup",
                "codedeploy:GetApplication",
                "codedeploy:GetApplicationRevision",
                "codedeploy:GetDeployment",
                "codedeploy:GetDeploymentConfig",
                "codedeploy:GetDeploymentGroup",
                "codedeploy:GetDeploymentTarget",
                "codedeploy:ListApplicationRevisions",
                "codedeploy:ListApplications",
                "codedeploy:ListDeploymentConfigs",
                "codedeploy:ListDeploymentGroups",
                "codedeploy:ListDeployments",
                "codedeploy:ListDeploymentTargets",
                "codedeploy:RegisterApplicationRevision",
                "codedeploy:StopDeployment",
                "ec2:AssociateRouteTable",
                "ec2:AttachInternetGateway",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CancelSpotFleetRequests",
                "ec2:CreateInternetGateway",
                "ec2:CreateLaunchTemplate",
                "ec2:CreateRoute",
                "ec2:CreateRouteTable",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSubnet",
                "ec2:CreateVpc",
                "ec2:DeleteLaunchTemplate",
                "ec2:DeleteSubnet",
                "ec2:DeleteVpc",
                "ec2:Describe*",
                "ec2:DetachInternetGateway",
                "ec2:DisassociateRouteTable",
                "ec2:ModifySubnetAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:RequestSpotFleet",
                "ec2:RunInstances",
                "ecs:*",
                "elasticfilesystem:DescribeAccessPoints",
                "elasticfilesystem:DescribeFileSystems",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "events:DeleteRule",
                "events:DescribeRule",
                "events:ListRuleNamesByTarget",
                "events:ListTargetsByRule",
                "events:PutRule",
                "events:PutTargets",
                "events:RemoveTargets",
                "fsx:DescribeFileSystems",
                "iam:ListAttachedRolePolicies",
                "iam:ListInstanceProfiles",
                "iam:ListRoles",
                "lambda:ListFunctions",
                "logs:CreateLogGroup",
                "logs:DescribeLogGroups",
                "logs:FilterLogEvents",
                "route53:CreateHostedZone",
                "route53:DeleteHostedZone",
                "route53:GetHealthCheck",
                "route53:GetHostedZone",
                "route53:ListHostedZonesByName",
                "servicediscovery:CreatePrivateDnsNamespace",
                "servicediscovery:CreateService",
                "servicediscovery:DeleteService",
                "servicediscovery:GetNamespace",
                "servicediscovery:GetOperation",
                "servicediscovery:GetService",
                "servicediscovery:ListNamespaces",
                "servicediscovery:ListServices",
                "servicediscovery:UpdateService",
                "sns:ListTopics"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "SSMPolicy",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/aws/service/ecs*"
        },
        {
            "Sid": "ManagedCloudformationResourcesCleanupPolicy",
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteInternetGateway",
                "ec2:DeleteRoute",
                "ec2:DeleteRouteTable",
                "ec2:DeleteSecurityGroup"
            ],
            "Resource": [
                "*"
            ],
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/aws:cloudformation:stack-name": "EC2ContainerService-*"
                }
            }
        },
        {
            "Sid": "TasksPassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "*"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": "ecs-tasks.amazonaws.com"
                }
            }
        },
        {
            "Sid": "InfrastructurePassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/ecsInfrastructureRole"
            ],
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "ecs.amazonaws.com"
                }
            }
        },
        {
            "Sid": "InstancePassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/ecsInstanceRole*"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "ec2.amazonaws.com.cn"
                    ]
                }
            }
        },
        {
            "Sid": "AutoScalingPassRolePolicy",
            "Action": "iam:PassRole",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/ecsAutoscaleRole*"
            ],
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "application-autoscaling.amazonaws.com",
                        "application-autoscaling.amazonaws.com.cn"
                    ]
                }
            }
        },
        {
            "Sid": "ServiceLinkedRoleCreationPolicy",
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": [
                        "ecs.amazonaws.com",
                        "autoscaling.amazonaws.com",
                        "ecs.application-autoscaling.amazonaws.com",
                        "spot.amazonaws.com",
                        "spotfleet.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "ELBTaggingPolicy",
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:AddTags"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "elasticloadbalancing:CreateAction": [
                        "CreateTargetGroup",
                        "CreateRule",
                        "CreateListener",
                        "CreateLoadBalancer"
                    ]
                }
            }
        }
    ]
}
```

</details>

- **III. `AmazonRDSReadOnlyAccess`**
  - Provides read only access to Amazon RDS via the AWS Management Console.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:Describe*",
                "rds:ListTagsForResource",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcs"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricData",
                "logs:DescribeLogStreams",
                "logs:GetLogEvents",
                "devops-guru:GetResourceCollection"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "devops-guru:SearchInsights",
                "devops-guru:ListAnomaliesForInsight"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "ForAllValues:StringEquals": {
                    "devops-guru:ServiceNames": [
                        "RDS"
                    ]
                },
                "Null": {
                    "devops-guru:ServiceNames": "false"
                }
            }
        }
    ]
}
```

</details>

- **IV. `AmazonVPCFullAccess`**
  - Provides full access to Amazon VPC via the AWS Management Console.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AmazonVPCFullAccess",
            "Effect": "Allow",
            "Action": [
                "ec2:AcceptVpcPeeringConnection",
                "ec2:AcceptVpcEndpointConnections",
                "ec2:AllocateAddress",
                "ec2:AssignIpv6Addresses",
                "ec2:AssignPrivateIpAddresses",
                "ec2:AssociateAddress",
                "ec2:AssociateDhcpOptions",
                "ec2:AssociateRouteTable",
                "ec2:AssociateSecurityGroupVpc",
                "ec2:AssociateSubnetCidrBlock",
                "ec2:AssociateVpcCidrBlock",
                "ec2:AttachClassicLinkVpc",
                "ec2:AttachInternetGateway",
                "ec2:AttachNetworkInterface",
                "ec2:AttachVpnGateway",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateCarrierGateway",
                "ec2:CreateCustomerGateway",
                "ec2:CreateDefaultSubnet",
                "ec2:CreateDefaultVpc",
                "ec2:CreateDhcpOptions",
                "ec2:CreateEgressOnlyInternetGateway",
                "ec2:CreateFlowLogs",
                "ec2:CreateInternetGateway",
                "ec2:CreateLocalGatewayRouteTableVpcAssociation",
                "ec2:CreateNatGateway",
                "ec2:CreateNetworkAcl",
                "ec2:CreateNetworkAclEntry",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:CreateRoute",
                "ec2:CreateRouteTable",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSubnet",
                "ec2:CreateTags",
                "ec2:CreateVpc",
                "ec2:CreateVpcEndpoint",
                "ec2:CreateVpcEndpointConnectionNotification",
                "ec2:CreateVpcEndpointServiceConfiguration",
                "ec2:CreateVpcPeeringConnection",
                "ec2:CreateVpnConnection",
                "ec2:CreateVpnConnectionRoute",
                "ec2:CreateVpnGateway",
                "ec2:DeleteCarrierGateway",
                "ec2:DeleteCustomerGateway",
                "ec2:DeleteDhcpOptions",
                "ec2:DeleteEgressOnlyInternetGateway",
                "ec2:DeleteFlowLogs",
                "ec2:DeleteInternetGateway",
                "ec2:DeleteLocalGatewayRouteTableVpcAssociation",
                "ec2:DeleteNatGateway",
                "ec2:DeleteNetworkAcl",
                "ec2:DeleteNetworkAclEntry",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNetworkInterfacePermission",
                "ec2:DeleteRoute",
                "ec2:DeleteRouteTable",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSubnet",
                "ec2:DeleteTags",
                "ec2:DeleteVpc",
                "ec2:DeleteVpcEndpoints",
                "ec2:DeleteVpcEndpointConnectionNotifications",
                "ec2:DeleteVpcEndpointServiceConfigurations",
                "ec2:DeleteVpcPeeringConnection",
                "ec2:DeleteVpnConnection",
                "ec2:DeleteVpnConnectionRoute",
                "ec2:DeleteVpnGateway",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeCarrierGateways",
                "ec2:DescribeClassicLinkInstances",
                "ec2:DescribeCustomerGateways",
                "ec2:DescribeDhcpOptions",
                "ec2:DescribeEgressOnlyInternetGateways",
                "ec2:DescribeFlowLogs",
                "ec2:DescribeInstances",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeIpv6Pools",
                "ec2:DescribeLocalGatewayRouteTables",
                "ec2:DescribeLocalGatewayRouteTableVpcAssociations",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeMovingAddresses",
                "ec2:DescribeNatGateways",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeNetworkInterfaceAttribute",
                "ec2:DescribeNetworkInterfacePermissions",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribePrefixLists",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroupReferences",
                "ec2:DescribeSecurityGroupRules",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupVpcAssociations",
                "ec2:DescribeStaleSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcClassicLink",
                "ec2:DescribeVpcClassicLinkDnsSupport",
                "ec2:DescribeVpcEndpointConnectionNotifications",
                "ec2:DescribeVpcEndpointConnections",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeVpcEndpointServiceConfigurations",
                "ec2:DescribeVpcEndpointServicePermissions",
                "ec2:DescribeVpcEndpointServices",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpnConnections",
                "ec2:DescribeVpnGateways",
                "ec2:DetachClassicLinkVpc",
                "ec2:DetachInternetGateway",
                "ec2:DetachNetworkInterface",
                "ec2:DetachVpnGateway",
                "ec2:DisableVgwRoutePropagation",
                "ec2:DisableVpcClassicLink",
                "ec2:DisableVpcClassicLinkDnsSupport",
                "ec2:DisassociateAddress",
                "ec2:DisassociateRouteTable",
                "ec2:DisassociateSecurityGroupVpc",
                "ec2:DisassociateSubnetCidrBlock",
                "ec2:DisassociateVpcCidrBlock",
                "ec2:EnableVgwRoutePropagation",
                "ec2:EnableVpcClassicLink",
                "ec2:EnableVpcClassicLinkDnsSupport",
                "ec2:GetSecurityGroupsForVpc",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:ModifySecurityGroupRules",
                "ec2:ModifySubnetAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifyVpcEndpoint",
                "ec2:ModifyVpcEndpointConnectionNotification",
                "ec2:ModifyVpcEndpointServiceConfiguration",
                "ec2:ModifyVpcEndpointServicePermissions",
                "ec2:ModifyVpcPeeringConnectionOptions",
                "ec2:ModifyVpcTenancy",
                "ec2:MoveAddressToVpc",
                "ec2:RejectVpcEndpointConnections",
                "ec2:RejectVpcPeeringConnection",
                "ec2:ReleaseAddress",
                "ec2:ReplaceNetworkAclAssociation",
                "ec2:ReplaceNetworkAclEntry",
                "ec2:ReplaceRoute",
                "ec2:ReplaceRouteTableAssociation",
                "ec2:ResetNetworkInterfaceAttribute",
                "ec2:RestoreAddressToClassic",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:UnassignIpv6Addresses",
                "ec2:UnassignPrivateIpAddresses",
                "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
                "ec2:UpdateSecurityGroupRuleDescriptionsIngress"
            ],
            "Resource": "*"
        }
    ]
}
```

</details>

- **V. `AWSCodeBuildAdminAccess`**
  - Provides full access to AWS CodeBuild via the AWS Management Console. Also attach AmazonS3ReadOnlyAccess to provide access to download build artifacts, and attach IAMFullAccess to create and manage the service role for CodeBuild.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSServicesAccess",
            "Action": [
                "codebuild:*",
                "codecommit:GetBranch",
                "codecommit:GetCommit",
                "codecommit:GetRepository",
                "codecommit:ListBranches",
                "codecommit:ListRepositories",
                "cloudwatch:GetMetricStatistics",
                "ec2:DescribeVpcs",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "elasticfilesystem:DescribeFileSystems",
                "events:DeleteRule",
                "events:DescribeRule",
                "events:DisableRule",
                "events:EnableRule",
                "events:ListTargetsByRule",
                "events:ListRuleNamesByTarget",
                "events:PutRule",
                "events:PutTargets",
                "events:RemoveTargets",
                "logs:GetLogEvents",
                "s3:GetBucketLocation",
                "s3:ListAllMyBuckets"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Sid": "CWLDeleteLogGroupAccess",
            "Action": [
                "logs:DeleteLogGroup"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:logs:*:*:log-group:/aws/codebuild/*:log-stream:*"
        },
        {
            "Sid": "SSMParameterWriteAccess",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/CodeBuild/*"
        },
        {
            "Sid": "SSMStartSessionAccess",
            "Effect": "Allow",
            "Action": [
                "ssm:StartSession"
            ],
            "Resource": "arn:aws:ecs:*:*:task/*/*"
        },
        {
            "Sid": "CodeStarConnectionsReadWriteAccess",
            "Effect": "Allow",
            "Action": [
                "codestar-connections:CreateConnection",
                "codestar-connections:DeleteConnection",
                "codestar-connections:UpdateConnectionInstallation",
                "codestar-connections:TagResource",
                "codestar-connections:UntagResource",
                "codestar-connections:ListConnections",
                "codestar-connections:ListInstallationTargets",
                "codestar-connections:ListTagsForResource",
                "codestar-connections:GetConnection",
                "codestar-connections:GetIndividualAccessToken",
                "codestar-connections:GetInstallationUrl",
                "codestar-connections:PassConnection",
                "codestar-connections:StartOAuthHandshake",
                "codestar-connections:UseConnection"
            ],
            "Resource": [
                "arn:aws:codestar-connections:*:*:connection/*",
                "arn:aws:codeconnections:*:*:connection/*"
            ]
        },
        {
            "Sid": "CodeStarNotificationsReadWriteAccess",
            "Effect": "Allow",
            "Action": [
                "codestar-notifications:CreateNotificationRule",
                "codestar-notifications:DescribeNotificationRule",
                "codestar-notifications:UpdateNotificationRule",
                "codestar-notifications:DeleteNotificationRule",
                "codestar-notifications:Subscribe",
                "codestar-notifications:Unsubscribe"
            ],
            "Resource": "*",
            "Condition": {
                "ArnLike": {
                    "codestar-notifications:NotificationsForResource": "arn:aws:codebuild:*:*:project/*"
                }
            }
        },
        {
            "Sid": "CodeStarNotificationsListAccess",
            "Effect": "Allow",
            "Action": [
                "codestar-notifications:ListNotificationRules",
                "codestar-notifications:ListEventTypes",
                "codestar-notifications:ListTargets",
                "codestar-notifications:ListTagsforResource"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CodeStarNotificationsSNSTopicCreateAccess",
            "Effect": "Allow",
            "Action": [
                "sns:CreateTopic",
                "sns:SetTopicAttributes"
            ],
            "Resource": "arn:aws:sns:*:*:codestar-notifications*"
        },
        {
            "Sid": "SNSTopicListAccess",
            "Effect": "Allow",
            "Action": [
                "sns:ListTopics",
                "sns:GetTopicAttributes"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CodeStarNotificationsChatbotAccess",
            "Effect": "Allow",
            "Action": [
                "chatbot:DescribeSlackChannelConfigurations",
                "chatbot:ListMicrosoftTeamsChannelConfigurations"
            ],
            "Resource": "*"
        }
    ]
}
```

</details>

- **VI. `CloudWatchLogsFullAccess`**
  - Provides full access to AWS CodeBuild via the AWS Management Console. Also attach AmazonS3ReadOnlyAccess to provide access to download build artifacts, and attach IAMFullAccess to create and manage the service role for CodeBuild.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchLogsFullAccess",
            "Effect": "Allow",
            "Action": [
                "logs:*",
                "cloudwatch:GenerateQuery"
            ],
            "Resource": "*"
        }
    ]
}
```

</details>

- **VII. `CodeBuildBasePolicy-codebuild-ror-app-role-ap-south-1`**
  - Customer managed
  
<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:ap-south-1:339713104321:log-group:/aws/codebuild/ror-chat-app-build",
                "arn:aws:logs:ap-south-1:339713104321:log-group:/aws/codebuild/ror-chat-app-build:*"
            ],
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ]
        },
        {
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::codepipeline-ap-south-1-*"
            ],
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:GetBucketAcl",
                "s3:GetBucketLocation"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "codebuild:CreateReportGroup",
                "codebuild:CreateReport",
                "codebuild:UpdateReport",
                "codebuild:BatchPutTestCases",
                "codebuild:BatchPutCodeCoverages"
            ],
            "Resource": [
                "arn:aws:codebuild:ap-south-1:339713104321:report-group/ror-chat-app-build-*"
            ]
        }
    ]
}
```

</details>

- **VIII. `CodeBuildCodeConnectionsSourceCredentialsPolicy-ror-chat-app-build-ap-south-1-339713104321`**
  - Policy used in trust relationship with CodeBuild
  - Customer managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "codestar-connections:GetConnectionToken",
                "codestar-connections:GetConnection",
                "codeconnections:GetConnectionToken",
                "codeconnections:GetConnection",
                "codeconnections:UseConnection"
            ],
            "Resource": [
                "arn:aws:codestar-connections:ap-south-1:339713104321:connection/e78bca79-a1be-4f00-9f47-58e0d3058c09",
                "arn:aws:codeconnections:ap-south-1:339713104321:connection/e78bca79-a1be-4f00-9f47-58e0d3058c09"
            ]
        }
    ]
}
```

</details>

- **IX. `CodeBuildSecretsManagerPolicy-chat-app-ap-south-1`**
  - Policy used in trust relationship with CodeBuild
  - Customer managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "arn:aws:secretsmanager:ap-south-1:339713104321:secret:/CodeBuild/*"
            ]
        }
    ]
}
```

</details>

- **X. `SecretsManagerReadWrite`**
  - Provides read/write access to AWS Secrets Manager via the AWS Management Console. Note: this exludes IAM actions, so combine with IAMFullAccess if rotation configuration is required.
  - AWS managed

<details>
  <summary>Click to view given Permissions through JSON Format</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "BasePermissions",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:*",
                "cloudformation:CreateChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:DescribeStackResource",
                "cloudformation:DescribeStacks",
                "cloudformation:ExecuteChangeSet",
                "docdb-elastic:GetCluster",
                "docdb-elastic:ListClusters",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs",
                "kms:DescribeKey",
                "kms:ListAliases",
                "kms:ListKeys",
                "lambda:ListFunctions",
                "rds:DescribeDBClusters",
                "rds:DescribeDBInstances",
                "redshift:DescribeClusters",
                "redshift-serverless:ListWorkgroups",
                "redshift-serverless:GetNamespace",
                "tag:GetResources"
            ],
            "Resource": "*"
        },
        {
            "Sid": "LambdaPermissions",
            "Effect": "Allow",
            "Action": [
                "lambda:AddPermission",
                "lambda:CreateFunction",
                "lambda:GetFunction",
                "lambda:InvokeFunction",
                "lambda:UpdateFunctionConfiguration"
            ],
            "Resource": "arn:aws:lambda:*:*:function:SecretsManager*"
        },
        {
            "Sid": "SARPermissions",
            "Effect": "Allow",
            "Action": [
                "serverlessrepo:CreateCloudFormationChangeSet",
                "serverlessrepo:GetApplication"
            ],
            "Resource": "arn:aws:serverlessrepo:*:*:applications/SecretsManager*"
        },
        {
            "Sid": "S3Permissions",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": [
                "arn:aws:s3:::awsserverlessrepo-changesets*",
                "arn:aws:s3:::secrets-manager-rotation-apps-*/*"
            ]
        }
    ]
}
```

</details>

</details>

### 3. **Give Role a Name**

Example:
```
codebuild-ror-app-role
```

### 4. **Finish and Create Role**
---

# CI/CD Pipeline Deployment of Ruby on Rails Application (Without ECS)

This guide walks through deploying a Dockerized Ruby on Rails application using AWS services including **EC2, CodeBuild, CodeDeploy, and CodePipeline.**

---

## 🧱 Step 1: Launch EC2 Instances for CodeDeploy

1. Navigate to **EC2 > Launch Instance**
2. Select **Amazon Linux 2** or **Ubuntu**
3. Choose instance type: `t2.micro` or higher
4. Configure Security Group:
   - Allow **SSH (22)** from your IP
   - Allow **HTTP (80)** or the app port (e.g., 3000)

5. In **User Data**, use the following script to install Docker & CodeDeploy agent:

```bash
# Update package index and install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl jq ruby

# Install Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install CodeDeploy agent
sudo apt update
sudo apt install ruby -y
wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent
systemctl status codedeploy-agent
```

---

## 🏷️ Step 2: Tag EC2 Instances

1. Go to your EC2 instance
2. Add the following **Tags**:
   - **Key:** `Name`
   - **Value:** `CodeDeployInstance`

> ⚠️ Ensure this matches the tag configured in `appspec.yml`

---

## 🔐 Step 3: Create IAM Role for EC2 Instance

### Create `EC2CodeDeployRole`:

1. Go to **IAM > Roles > Create Role**
2. Trusted entity: **EC2**
3. Attach the following permissions:
   - `AmazonEC2RoleforAWSCodeDeploy`
   - `AmazonEC2ContainerRegistryReadOnly`
   - `AmazonS3ReadOnlyAccess`
   - Custom **ECR Pull Policy**:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "ecr:GetAuthorizationToken",
             "ecr:BatchCheckLayerAvailability",
             "ecr:GetDownloadUrlForLayer",
             "ecr:BatchGetImage"
           ],
           "Resource": "*"
         }
       ]
     }
     ```
   - Custom **Secrets Manager Access**:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": "secretsmanager:GetSecretValue",
           "Resource": "arn:aws:secretsmanager:ap-south-1:339713104321:secret:chat-app-secrets-rXZYzv"
         }
       ]
     }
     ```
4. Name the role: `EC2CodeDeployRole`
5. Attach it to the EC2 instance

---

## 👷 Step 4: Create IAM Role for CodeDeploy

### Create `AWSCodeDeployRole`:

1. Go to **IAM > Roles > Create Role**
2. Trusted entity: **AWS Service**
3. Use Case: **CodeDeploy – EC2**
4. Attach **Managed Policy**: `AWSCodeDeployRole`

> ✅ You may use the AWS managed policy or a custom version:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:Get*",
        "tag:GetTags",
        "autoscaling:CompleteLifecycleAction",
        "autoscaling:DeleteLifecycleHook",
        "autoscaling:Describe*",
        "autoscaling:Get*",
        "autoscaling:PutLifecycleHook",
        "autoscaling:PutNotificationConfiguration",
        "autoscaling:RecordLifecycleActionHeartbeat",
        "autoscaling:UpdateAutoScalingGroup",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:PutMetricAlarm",
        "codedeploy:*",
        "iam:PassRole",
        "s3:Get*",
        "s3:List*"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 🚚 Step 5: Create CodeDeploy Application

1. Go to **CodeDeploy > Applications > Create Application**
2. Name: `RoRApp`
3. Compute platform: **EC2/On-Premises**

### Create Deployment Group

1. Name: `RoRAppDeploymentGroup`
2. Service Role: Select IAM role with `AWSCodeDeployRole`
3. Deployment type: **In-place**
4. Environment configuration:
   - Select **Amazon EC2 instances**
   - Filter by tag: `Name=CodeDeployInstance`
   - Disable Load Balancer
5. Deployment settings:
   - Deployment configuration: `CodeDeployDefault.AllAtOnce`

---

## 🛠️ Step 6: Update CodeBuild - `buildspec.yml`

Ensure artifacts are properly uploaded for CodeDeploy to use:

```yaml
artifacts:
  files:
    - appspec.yml
    - scripts/*
```

---

## ⚙️ Step 7: Create CodePipeline

1. Go to **CodePipeline > Create Pipeline**
2. **Pipeline Settings**:
   - Choose a name for your pipeline

3. **Source Stage**:
   - Source: GitHub / CodeCommit

4. **Build Stage**:
   - Provider: **AWS CodeBuild**
   - Use pre-configured build project

5. **Deploy Stage**:
   - Provider: **AWS CodeDeploy**
   - Application Name: `RoRApp`
   - Deployment Group: `RoRAppDeploymentGroup`
   - Artifacts: Use CodeBuild output

> 🧠 **Tip**: Provide necessary environment variables for secrets and configurations when deploying.

---

## Step 8: Verify Docker Container on EC2

After deployment, SSH into your EC2 instance and run the following commands to check if your Rails app container is running correctly:

```bash
# List running Docker containers
sudo docker ps

# View logs of the container (replace <container_id> with actual ID)
sudo docker logs <container_id>

# Confirm the container is still running
sudo docker ps

# Access the running container’s bash shell (replace <container_id> accordingly)
sudo docker exec -it <container_id> /bin/bash
```

> 💡 You can get the `<container_id>` from the `sudo docker ps` output. This helps you debug or inspect your app inside the container.

---



