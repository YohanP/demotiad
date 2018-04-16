#!/bin/bash
set -ex

if [ -z "$STATE_BUCKET" -o -z "$BLUE_STATE_KEY" -o -z "$GREEN_STATE_KEY" -o -z "$APP_DIR" -o -z "$REPO_NAME" ]
then
    echo 'Missing parameters'
    exit 0
fi

COMMIT=${TRAVIS_COMMIT:-'unknown'}
SHORT_COMMIT=${COMMIT:0:7}

ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)

echo "Building image"
docker build -t $REPO_NAME:$SHORT_COMMIT --build-arg version=$SHORT_COMMIT $APP_DIR

echo "Tagging image"
docker tag $REPO_NAME:$SHORT_COMMIT $REPO_NAME:latest
docker tag $REPO_NAME:$SHORT_COMMIT ${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${SHORT_COMMIT}
docker tag $REPO_NAME:$SHORT_COMMIT ${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:latest

docker images

echo "Logging to ECR"
$(aws ecr --region $AWS_REGION get-login i--no-include-email)

echo "Pushing image"
docker push ${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:${SHORT_COMMIT}
docker push ${ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}:latest

echo "Getting current environment"
HEADER_COLOR=$(curl -si http://$WEBSITE  | grep X-Color || echo "")
if [ "$HEADER_COLOR" == "" ]
then
    echo "Unable to detect site"
    exit 0
fi
COLOR=${HEADER_COLOR#X-Color:}
COLOR=${COLOR//[$'\t\r\n ']}

echo "Current deployement is $COLOR"
if [ "$COLOR" == "blue" ]
then
    NEXT='green'
else
    NEXT='blue'
fi

echo "Updating $NEXT stack"
pushd ${TRAVIS_BUILD_DIR}/${TERRAFORM_DIR}/${NEXT}
rm -rf .terraform
export AWS_DEFAULT_REGION=$AWS_REGION
terraform init
TF_VAR_voteapp_tag=${SHORT_COMMIT} terraform plan
TF_VAR_voteapp_tag=${SHORT_COMMIT} terraform apply
popd
