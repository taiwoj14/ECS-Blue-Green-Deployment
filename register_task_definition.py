import boto3
import json

# Define your ECS cluster name and task definition family
TASK_DEFINITION_FAMILY = "app-task"
NEW_IMAGE = "josepht05/petclinic-1"  # Replace with your Docker Hub image
CONTAINER_NAME = "app"  # Replace with your container name
CLUSTER_NAME = "main-cluster"
DEPLOYMENT_GROUP_NAME = "ecs-dg"
APPLICATION_NAME = "ecs-app"
CONTAINER_PORT = 5000  # Replace with your container port if different

# Create a Boto3 ECS client
ecs_client = boto3.client('ecs')
codedeploy_client = boto3.client('codedeploy')

# Retrieve the latest task definition for the family
response = ecs_client.list_task_definitions(familyPrefix=TASK_DEFINITION_FAMILY, sort='DESC', maxResults=1)
task_definition_arn = response['taskDefinitionArns'][0]

# Describe the latest task definition
response = ecs_client.describe_task_definition(taskDefinition=task_definition_arn)
task_definition = response['taskDefinition']

# Update the container definition with the new image
for container in task_definition['containerDefinitions']:
    if container['name'] == CONTAINER_NAME:
        container['image'] = NEW_IMAGE

# Register the new task definition
response = ecs_client.register_task_definition(
    family=TASK_DEFINITION_FAMILY,
    containerDefinitions=task_definition['containerDefinitions'],
    volumes=task_definition.get('volumes', []),
    taskRoleArn=task_definition.get('taskRoleArn'),
    executionRoleArn=task_definition.get('executionRoleArn'),
    networkMode=task_definition.get('networkMode', 'bridge'),
    requiresCompatibilities=task_definition.get('requiresCompatibilities', []),
    cpu=task_definition.get('cpu'),
    memory=task_definition.get('memory'),
)

# Output the new task definition ARN
new_task_definition_arn = response['taskDefinition']['taskDefinitionArn']
print(f"New task definition registered: {new_task_definition_arn}")

# Trigger a CodeDeploy deployment
codedeploy_client.create_deployment(
    applicationName=APPLICATION_NAME,
    deploymentGroupName=DEPLOYMENT_GROUP_NAME,
    revision={
        'revisionType': 'AppSpecContent',
        'appSpecContent': {
            'content': json.dumps({
                'version': 1,
                'Resources': [
                    {
                        'TargetService': {
                            'Type': 'AWS::ECS::Service',
                            'Properties': {
                                'TaskDefinition': new_task_definition_arn,
                                'LoadBalancerInfo': {
                                    'ContainerName': CONTAINER_NAME,
                                    'ContainerPort': CONTAINER_PORT
                                }
                            }
                        }
                    }
                ],
                'Hooks': []  # No hooks defined
            })
        }
    },
    deploymentConfigName='CodeDeployDefault.ECSAllAtOnce'  # Adjust as needed
)
print(f"CodeDeploy deployment triggered for task definition: {new_task_definition_arn}")

