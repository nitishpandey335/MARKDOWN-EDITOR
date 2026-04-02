// ─────────────────────────────────────────────────────────────────
// Jenkinsfile — CI/CD Pipeline for Markdown Editor
//
// Flow:
//   GitHub push → Jenkins webhook → this pipeline runs →
//   builds Docker images → pushes to Docker Hub →
//   deploys to Kubernetes via kubectl
// ─────────────────────────────────────────────────────────────────

pipeline {
    // Run on any available Jenkins agent
    agent any

    // ── Environment variables available to all stages ──
    environment {
        // Docker Hub credentials (configured in Jenkins → Manage Credentials)
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME    = 'nitishpandey335'

        // Image names
        BACKEND_IMAGE  = "${DOCKERHUB_USERNAME}/markdown-backend"
        FRONTEND_IMAGE = "${DOCKERHUB_USERNAME}/markdown-frontend"

        // Tag images with the Git commit SHA for traceability
        IMAGE_TAG = "${env.GIT_COMMIT?.take(7) ?: 'latest'}"

        // Kubernetes namespace
        K8S_NAMESPACE = 'markdown-editor'

        // Path to kubeconfig on the Jenkins agent
        KUBECONFIG = '/var/lib/jenkins/.kube/config'
    }

    // ── Triggers ──
    triggers {
        // Poll GitHub every minute (or use a webhook for instant triggers)
        // For webhooks: configure GitHub → Settings → Webhooks → Jenkins URL
        githubPush()
    }

    // ── Pipeline options ──
    options {
        timeout(time: 30, unit: 'MINUTES')   // fail if pipeline takes > 30 min
        disableConcurrentBuilds()            // don't run two builds at once
        buildDiscarder(logRotator(numToKeepStr: '10'))  // keep last 10 builds
    }

    stages {

        // ── Stage 1: Checkout ──────────────────────────────────────
        stage('Checkout') {
            steps {
                echo "Checking out code from GitHub..."
                // Jenkins automatically checks out the repo that triggered the build
                checkout scm
            }
        }

        // ── Stage 2: Install Dependencies ─────────────────────────
        stage('Install Dependencies') {
            parallel {
                stage('Backend Dependencies') {
                    steps {
                        dir('backend') {
                            echo "Installing backend dependencies..."
                            sh 'npm ci'   // ci is faster and more reliable than install
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    steps {
                        dir('frontend') {
                            echo "Installing frontend dependencies..."
                            sh 'npm ci'
                        }
                    }
                }
            }
        }

        // ── Stage 3: Lint & Test ───────────────────────────────────
        stage('Lint & Test') {
            parallel {
                stage('Frontend Lint') {
                    steps {
                        dir('frontend') {
                            echo "Running ESLint..."
                            sh 'npm run lint'
                        }
                    }
                }
                stage('Frontend Build Test') {
                    steps {
                        dir('frontend') {
                            echo "Testing production build..."
                            sh 'npm run build'
                        }
                    }
                }
            }
        }

        // ── Stage 4: Build Docker Images ──────────────────────────
        stage('Build Docker Images') {
            parallel {
                stage('Build Backend Image') {
                    steps {
                        echo "Building backend Docker image: ${BACKEND_IMAGE}:${IMAGE_TAG}"
                        sh """
                            docker build \
                                -f docker/backend/Dockerfile \
                                -t ${BACKEND_IMAGE}:${IMAGE_TAG} \
                                -t ${BACKEND_IMAGE}:latest \
                                .
                        """
                    }
                }
                stage('Build Frontend Image') {
                    steps {
                        echo "Building frontend Docker image: ${FRONTEND_IMAGE}:${IMAGE_TAG}"
                        sh """
                            docker build \
                                -f docker/frontend/Dockerfile \
                                -t ${FRONTEND_IMAGE}:${IMAGE_TAG} \
                                -t ${FRONTEND_IMAGE}:latest \
                                .
                        """
                    }
                }
            }
        }

        // ── Stage 5: Push to Docker Hub ───────────────────────────
        stage('Push to Docker Hub') {
            steps {
                echo "Logging in to Docker Hub..."
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'

                echo "Pushing images..."
                sh """
                    docker push ${BACKEND_IMAGE}:${IMAGE_TAG}
                    docker push ${BACKEND_IMAGE}:latest
                    docker push ${FRONTEND_IMAGE}:${IMAGE_TAG}
                    docker push ${FRONTEND_IMAGE}:latest
                """
            }
            post {
                always {
                    // Always logout after push (security)
                    sh 'docker logout'
                }
            }
        }

        // ── Stage 6: Deploy to Kubernetes ─────────────────────────
        stage('Deploy to Kubernetes') {
            steps {
                echo "Deploying to Kubernetes namespace: ${K8S_NAMESPACE}"

                // Apply all K8s manifests (idempotent — safe to run multiple times)
                sh "kubectl apply -f k8s/namespace.yaml"
                sh "kubectl apply -f k8s/configmap.yaml"
                sh "kubectl apply -f k8s/secret.yaml"

                // Update the deployment image to the new tag
                // This triggers a rolling update automatically
                sh """
                    kubectl set image deployment/backend-deployment \
                        backend=${BACKEND_IMAGE}:${IMAGE_TAG} \
                        -n ${K8S_NAMESPACE}

                    kubectl set image deployment/frontend-deployment \
                        frontend=${FRONTEND_IMAGE}:${IMAGE_TAG} \
                        -n ${K8S_NAMESPACE}
                """

                // Apply services, ingress, HPA
                sh "kubectl apply -f k8s/backend-service.yaml"
                sh "kubectl apply -f k8s/frontend-service.yaml"
                sh "kubectl apply -f k8s/ingress.yaml"
                sh "kubectl apply -f k8s/hpa.yaml"

                // Wait for rollout to complete (timeout 5 min)
                sh """
                    kubectl rollout status deployment/backend-deployment \
                        -n ${K8S_NAMESPACE} --timeout=5m

                    kubectl rollout status deployment/frontend-deployment \
                        -n ${K8S_NAMESPACE} --timeout=5m
                """

                echo "Deployment successful!"
            }
        }

        // ── Stage 7: Smoke Test ────────────────────────────────────
        stage('Smoke Test') {
            steps {
                echo "Running post-deployment smoke test..."
                // Wait a few seconds for pods to be fully ready
                sh 'sleep 10'
                // Check that pods are running
                sh "kubectl get pods -n ${K8S_NAMESPACE}"
            }
        }
    }

    // ── Post-pipeline actions ──────────────────────────────────────
    post {
        success {
            echo "Pipeline succeeded! Image tag: ${IMAGE_TAG}"
            // Add Slack/email notification here if needed
        }
        failure {
            echo "Pipeline FAILED. Check logs above."
            // Rollback on failure
            sh """
                kubectl rollout undo deployment/backend-deployment -n ${K8S_NAMESPACE} || true
                kubectl rollout undo deployment/frontend-deployment -n ${K8S_NAMESPACE} || true
            """
        }
        always {
            // Clean up dangling Docker images to save disk space
            sh 'docker image prune -f'
        }
    }
}
