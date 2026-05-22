// Pulse CI/CD pipeline.
// Builds the container images, runs the 66 backend tests, and (optionally)
// pushes images to ECR. ECR account ID is parameterised — set ECR_REGISTRY
// and AWS_REGION below or as Jenkins environment variables.
pipeline {
    agent any

    environment {
        // Override these for your own AWS account, e.g.
        //   123456789012.dkr.ecr.eu-central-1.amazonaws.com
        ECR_REGISTRY = "${env.ECR_REGISTRY ?: 'CHANGE_ME.dkr.ecr.eu-central-1.amazonaws.com'}"
        AWS_REGION   = "${env.AWS_REGION ?: 'eu-central-1'}"
        IMAGE_TAG    = "${env.BUILD_NUMBER}"
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Backend tests (66)') {
            steps {
                sh '''
                    cd portal/backend
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --quiet -r requirements.txt
                    python -m pytest -v
                '''
            }
        }

        stage('Build images') {
            steps {
                sh '''
                    docker build -t pulse-backend:${IMAGE_TAG}      portal/backend
                    docker build -t pulse-frontend:${IMAGE_TAG}     portal/frontend
                    docker build -t pulse-url-shortener:${IMAGE_TAG} services/url-shortener
                '''
            }
        }

        stage('Push to ECR') {
            when {
                // Only push when a real registry has been configured.
                expression { return env.ECR_REGISTRY && !env.ECR_REGISTRY.startsWith('CHANGE_ME') }
            }
            steps {
                sh '''
                    aws ecr get-login-password --region ${AWS_REGION} \
                      | docker login --username AWS --password-stdin ${ECR_REGISTRY}

                    for svc in backend frontend url-shortener; do
                      docker tag  pulse-$svc:${IMAGE_TAG} ${ECR_REGISTRY}/pulse-$svc:${IMAGE_TAG}
                      docker tag  pulse-$svc:${IMAGE_TAG} ${ECR_REGISTRY}/pulse-$svc:latest
                      docker push ${ECR_REGISTRY}/pulse-$svc:${IMAGE_TAG}
                      docker push ${ECR_REGISTRY}/pulse-$svc:latest
                    done
                '''
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded — images built and tests passed (build ${IMAGE_TAG})."
        }
        failure {
            echo "Pipeline failed — check the stage logs above."
        }
        always {
            sh 'docker image prune -f || true'
        }
    }
}
