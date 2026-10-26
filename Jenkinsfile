// ------------------------------------------------------------------
// User Management - BACKEND app pipeline (Day 4, EKS)   job name: um-backend
//   build image (Maven runs inside Docker) -> push to ECR -> deploy to EKS
//   -> wait for the rolling update -> verify (API, S3 photo, Redis cache)
// Needs: the um-infra pipeline has run "apply" (cluster, ECR, PostgreSQL, Redis).
// ------------------------------------------------------------------
pipeline {
    agent any

    parameters {
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region of the cluster')
    }

    options {
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        APP                = 'backend'
        CLUSTER_NAME       = 'um-eks'
        NAMESPACE          = 'user-management'
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        IMAGE_TAG          = "${BUILD_NUMBER}"          // every build gets its own image version
        KUBECONFIG         = "${WORKSPACE}/.kubeconfig"
    }

    stages {

        stage('Check infra') {
            steps {
                script {
                    def account = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                    env.REGISTRY = "${account}.dkr.ecr.${params.AWS_REGION}.amazonaws.com"
                    env.IMAGE    = "${env.REGISTRY}/um-${env.APP}:${env.IMAGE_TAG}"
                }
                sh '''
                    if ! aws eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
                        echo "EKS cluster $CLUSTER_NAME not found - run the um-infra pipeline (apply) first"
                        exit 1
                    fi
                    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_DEFAULT_REGION"
                    kubectl get namespace "$NAMESPACE" >/dev/null || {
                        echo "Namespace $NAMESPACE missing - run the um-infra pipeline (apply) first"; exit 1; }
                    echo "Will build and deploy: $IMAGE"
                '''
            }
        }

        stage('Build image') {
            steps {
                // The Dockerfile compiles the code with Maven, so Jenkins needs no Java/Maven
                sh 'docker build -t "$IMAGE" .'
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    # Log in to ECR with the Jenkins IAM role (no password stored anywhere)
                    aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"
                    docker push "$IMAGE"
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    # Put this build's image into the manifest and apply it
                    sed "s#IMAGE_PLACEHOLDER#$IMAGE#" k8s/backend.yaml | kubectl apply -f -
                    kubectl apply -f k8s/hpa.yaml
                '''
            }
        }

        stage('Wait for rolling update') {
            steps {
                // Fails if the new pods never become ready - the old pods keep serving users
                sh 'kubectl -n "$NAMESPACE" rollout status deployment/backend --timeout=600s'
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    # Reach the backend Service from Jenkins through a temporary tunnel
                    kubectl -n "$NAMESPACE" port-forward svc/backend 18080:8080 > port-forward.log 2>&1 &
                    PF=$!
                    trap 'kill $PF 2>/dev/null' EXIT
                    for i in $(seq 1 30); do
                        curl -fs -o /dev/null http://localhost:18080/actuator/health/readiness && break
                        sleep 2
                    done
                    API=http://localhost:18080/api/users

                    echo "Checking API"
                    curl -fsS "$API" > /dev/null

                    echo "Checking photo upload to S3"
                    curl -s -o /dev/null -X POST "$API" -H 'Content-Type: application/json' \
                         -d '{"name":"Pipeline Check","email":"pipeline-check@example.com","password":"pipeline123"}'
                    USER_ID=$(curl -fsS "$API" | python3 -c 'import sys,json; print(next(u["id"] for u in json.load(sys.stdin) if u["email"]=="pipeline-check@example.com"))')
                    echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d > check.png
                    curl -fsS -F "file=@check.png;type=image/png" "$API/$USER_ID/photo" -o upload.json
                    PHOTO_URL=$(python3 -c 'import json; print(json.load(open("upload.json"))["photoUrl"])')
                    curl -fsS -o downloaded.png "$PHOTO_URL"
                    cmp -s check.png downloaded.png
                    echo "Photo stored in S3 and readable through a pre-signed URL (pod IAM role works)"

                    FIRST=$(curl -fsS -o /dev/null -w '%{time_total}' "$API")
                    SECOND=$(curl -fsS -o /dev/null -w '%{time_total}' "$API")
                    echo "User list: 1st call (database) ${FIRST}s, 2nd call (Redis cache) ${SECOND}s"

                    echo "=============================================================="
                    echo " BACKEND DEPLOYED: $IMAGE"
                    kubectl -n "$NAMESPACE" get pods -l app=backend -o wide
                    kubectl -n "$NAMESPACE" get hpa backend
                    echo "=============================================================="
                '''
            }
        }
    }

    post {
        always {
            // keep the Jenkins disk clean - the image is safely stored in ECR
            sh 'docker image rm "$IMAGE" 2>/dev/null || true'
        }
        failure {
            echo 'Build failed: open the red stage above and read the last error lines.'
        }
    }
}
