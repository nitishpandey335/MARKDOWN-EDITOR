pipeline {
    agent any

    environment {
        DOCKERHUB_USERNAME = 'nitishpandey335'

        BACKEND_IMAGE = "${DOCKERHUB_USERNAME}/markdown-backend"
        FRONTEND_IMAGE = "${DOCKERHUB_USERNAME}/markdown-frontend"

        IMAGE_TAG = "${env.GIT_COMMIT?.take(7) ?: 'latest'}"

        K8S_NAMESPACE = 'markdown-editor'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Images') {
            steps {
                sh """
                docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} -f docker/backend/Dockerfile .
                docker build -t ${FRONTEND_IMAGE}:${IMAGE_TAG} -f docker/frontend/Dockerfile .
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'USER', passwordVariable: 'PASS')]) {

                    sh 'echo $PASS | docker login -u $USER --password-stdin'

                    sh """
                    docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                    docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                    """
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh """
                kubectl set image deployment/backend-deployment backend=${BACKEND_IMAGE}:${IMAGE_TAG} -n ${K8S_NAMESPACE} || true
                kubectl set image deployment/frontend-deployment frontend=${FRONTEND_IMAGE}:${IMAGE_TAG} -n ${K8S_NAMESPACE} || true
                """
            }
        }
    }

    post {
        success {
            echo 'SUCCESS 🚀'
        }
        failure {
            echo 'FAILED ❌'
        }
        always {
            echo 'Pipeline completed'
        }
    }
}
