// Pulse CI/CD pipeline (Option 1: artifact-based delivery, no registry).
// Builds the images, runs the 66 backend tests, and — on success — saves the
// backend image as a tarball and archives it. The local deploy-local.sh script
// downloads that artifact and deploys it to local minikube, so minikube runs the exact
// image this pipeline built and tested.
pipeline {
    agent any

    environment {
        IMAGE_TAG = "${env.BUILD_NUMBER}"
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
                    docker build -t pulse-backend:${IMAGE_TAG}       portal/backend
                    docker build -t pulse-frontend:${IMAGE_TAG}      portal/frontend
                    docker build -t pulse-url-shortener:${IMAGE_TAG} services/url-shortener

                    # Also tag :latest so the deploy script can fetch a stable name
                    docker tag pulse-backend:${IMAGE_TAG}       pulse-backend:latest
                    docker tag pulse-frontend:${IMAGE_TAG}      pulse-frontend:latest
                    docker tag pulse-url-shortener:${IMAGE_TAG} pulse-url-shortener:latest
                '''
            }
        }

        stage('Save image artifacts') {
            steps {
                sh '''
                    # Save the built images as tarballs for the local deploy step.
                    docker save pulse-backend:latest       -o pulse-backend.tar
                    docker save pulse-frontend:latest      -o pulse-frontend.tar
                    docker save pulse-url-shortener:latest -o pulse-url-shortener.tar
                '''
                // Archive so they are downloadable via the Jenkins artifact API.
                archiveArtifacts artifacts: '*.tar', fingerprint: true
            }
        }
    }

    post {
        success {
            echo "Build ${IMAGE_TAG} passed — image artifacts archived and ready for deploy-local.sh."
        }
        failure {
            echo "Pipeline failed — nothing archived; deploy-local.sh will refuse to deploy."
        }
        always {
            sh 'rm -f *.tar || true'
            sh 'docker image prune -f || true'
        }
    }
}
