// ------------------------------------------------------------------
// User Management - Day 1 pipeline
//   apply   : Terraform (4 EC2 + S3 bucket + IAM role) -> Ansible (DB, Redis, backend, frontend) -> verify
//   destroy : Terraform removes everything
// Needs on the Jenkins server: terraform, ansible, git, curl
// Needs in Jenkins: Secret text credentials "um-db-password" and "um-redis-password"
// Needs AWS access: IAM role on the Jenkins EC2 with AmazonEC2FullAccess,
//                   AmazonS3FullAccess and IAMFullAccess (Day 2 creates a bucket + a role)
// ------------------------------------------------------------------
pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'],
               description: 'apply = create servers and deploy the app, destroy = delete everything')
        string(name: 'AWS_REGION', defaultValue: 'ap-south-1',
               description: 'AWS region for the three servers')
    }

    options {
        disableConcurrentBuilds()
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        TF_DIR             = 'infra/terraform'
        ANSIBLE_DIR        = 'infra/ansible'
        TF_IN_AUTOMATION   = 'true'
        TF_INPUT           = '0'
        TF_VAR_region      = "${params.AWS_REGION}"
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        ANSIBLE_FORCE_COLOR = 'false'
    }

    stages {

        stage('Check tools') {
            steps {
                sh '''
                    terraform -version
                    ansible --version | head -n 1
                    git --version
                '''
            }
        }

        stage('Terraform init') {
            steps {
                dir(env.TF_DIR) {
                    sh 'terraform init -no-color'
                }
            }
        }

        stage('Provision servers (Terraform)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir(env.TF_DIR) {
                    sh 'terraform apply -auto-approve -no-color'
                }
            }
        }

        stage('Ansible collections') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir(env.ANSIBLE_DIR) {
                    sh 'ansible-galaxy collection install -r requirements.yml'
                }
            }
        }

        stage('Configure database (Ansible)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([string(credentialsId: 'um-db-password', variable: 'DB_PASSWORD')]) {
                    dir(env.ANSIBLE_DIR) {
                        sh 'ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook db.yml'
                    }
                }
            }
        }

        stage('Configure Redis cache (Ansible)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([string(credentialsId: 'um-redis-password', variable: 'REDIS_PASSWORD')]) {
                    dir(env.ANSIBLE_DIR) {
                        sh 'ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook redis.yml'
                    }
                }
            }
        }

        stage('Deploy backend (Ansible: git pull, mvn, java -jar)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([string(credentialsId: 'um-db-password', variable: 'DB_PASSWORD'),
                                 string(credentialsId: 'um-redis-password', variable: 'REDIS_PASSWORD')]) {
                    dir(env.ANSIBLE_DIR) {
                        // deploy the same branch Jenkins is building (e.g. day-2)
                        sh 'ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook backend.yml ${GIT_BRANCH:+-e app_branch=${GIT_BRANCH#origin/}}'
                    }
                }
            }
        }

        stage('Deploy frontend (Ansible: git pull, npm ci, ng serve)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir(env.ANSIBLE_DIR) {
                    sh 'ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook frontend.yml ${GIT_BRANCH:+-e app_branch=${GIT_BRANCH#origin/}}'
                }
            }
        }

        stage('Verify app is running') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir(env.TF_DIR) {
                    sh '''
                        FRONTEND_URL=$(terraform output -raw frontend_url)
                        BACKEND_URL=$(terraform output -raw backend_url)

                        echo "Checking backend: $BACKEND_URL"
                        curl -fsS --retry 10 --retry-delay 6 --retry-all-errors "$BACKEND_URL"
                        echo

                        echo "Checking frontend: $FRONTEND_URL"
                        curl -fsS -o /dev/null --retry 20 --retry-delay 6 --retry-all-errors "$FRONTEND_URL"

                        # --- Day 2: photo upload to S3 -----------------------------------
                        echo "Checking photo upload to S3"
                        # a test user (409 'already exists' on later runs is fine)
                        curl -s -o /dev/null -X POST "$BACKEND_URL" -H 'Content-Type: application/json' \
                             -d '{"name":"Pipeline Check","email":"pipeline-check@example.com","password":"pipeline123"}'
                        USER_ID=$(curl -fsS "$BACKEND_URL" | python3 -c 'import sys,json; print(next(u["id"] for u in json.load(sys.stdin) if u["email"]=="pipeline-check@example.com"))')

                        # a tiny 1x1 PNG image
                        echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -d > check.png
                        curl -fsS -F "file=@check.png;type=image/png" "$BACKEND_URL/$USER_ID/photo" -o upload.json
                        PHOTO_URL=$(python3 -c 'import json; print(json.load(open("upload.json"))["photoUrl"])')

                        # the pre-signed link must download the same image from the private bucket
                        curl -fsS -o downloaded.png "$PHOTO_URL"
                        cmp -s check.png downloaded.png
                        echo "Photo stored in S3 and readable through a pre-signed URL"

                        # --- Day 3: cache ----------------------------------------------
                        # The upload above cleared the cache, so: 1st call = database, 2nd = Redis
                        FIRST=$(curl -fsS -o /dev/null -w '%{time_total}' "$BACKEND_URL")
                        SECOND=$(curl -fsS -o /dev/null -w '%{time_total}' "$BACKEND_URL")
                        echo "User list: 1st call (database) ${FIRST}s, 2nd call (Redis cache) ${SECOND}s"

                        echo "=============================================================="
                        echo " APP IS RUNNING"
                        echo " Open in browser : $FRONTEND_URL"
                        echo " Users API       : $BACKEND_URL"
                        echo " Photos bucket   : $(terraform output -raw photos_bucket)"
                        echo "=============================================================="
                    '''
                }
            }
        }

        stage('Destroy everything (Terraform)') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                dir(env.TF_DIR) {
                    sh 'terraform destroy -auto-approve -no-color'
                }
            }
        }
    }

    post {
        success {
            script {
                if (params.ACTION == 'apply') {
                    dir(env.TF_DIR) {
                        sh 'terraform output -no-color'
                    }
                }
            }
        }
        failure {
            echo 'Build failed: open the red stage above and read the last error lines.'
        }
    }
}
