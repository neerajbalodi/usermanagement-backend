// ------------------------------------------------------------------
// User Management - Day 1 pipeline
//   apply   : Terraform (3 EC2) -> Ansible (DB, backend, frontend) -> verify
//   destroy : Terraform removes everything
// Needs on the Jenkins server: terraform, ansible, git, curl
// Needs in Jenkins: Secret text credential with ID "um-db-password"
// Needs AWS access: IAM role on the Jenkins EC2 (AmazonEC2FullAccess)
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

        stage('Deploy backend (Ansible: git pull, mvn, java -jar)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([string(credentialsId: 'um-db-password', variable: 'DB_PASSWORD')]) {
                    dir(env.ANSIBLE_DIR) {
                        sh 'ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook backend.yml'
                    }
                }
            }
        }

        stage('Deploy frontend (Ansible: git pull, npm ci, ng serve)') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                dir(env.ANSIBLE_DIR) {
                    sh 'ANSIBLE_CONFIG=$PWD/ansible.cfg ansible-playbook frontend.yml'
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

                        echo "=============================================================="
                        echo " APP IS RUNNING"
                        echo " Open in browser : $FRONTEND_URL"
                        echo " Users API       : $BACKEND_URL"
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
