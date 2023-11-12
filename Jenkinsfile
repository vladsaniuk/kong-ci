pipeline {
    agent any
    parameters {
        choice(name: 'ENV', choices: ['dev', 'prod'], description: 'Env name')
        string(name: 'REGION', defaultValue: 'us-east-1', description: 'AWS region')
        choice(name: 'KONG_VERSION', choices: ['3.4.1.1', '2.8.4.4'], description: 'Kong LTS version')
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(
            artifactDaysToKeepStr: ("${BRANCH_NAME}" == 'main' && "${params.ENV}" == 'prod') ? '30' : '5',
            artifactNumToKeepStr: ("${BRANCH_NAME}" == 'main' && "${params.ENV}" == 'prod') ? '10' : '2',
            daysToKeepStr:  ("${BRANCH_NAME}" == 'main' && "${params.ENV}" == 'prod') ? '30' : '5',
            numToKeepStr:  ("${BRANCH_NAME}" == 'main' && "${params.ENV}" == 'prod') ? '30' : '10',
            ))
    }
    environment {
        TIMESTAMP = sh(script: 'date +%s',returnStdout: true).trim()
        APP_VERSION = "${KONG_VERSION}-${TIMESTAMP}-${BUILD_ID}"
        AWS_ACCESS_KEY_ID = credentials('aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_access_key')
    }

    stages {
        stage('Build image') {
            when {
                expression {
                    BRANCH_NAME == 'main'
                }
            }
            steps {
                script {
                    KONG_VERSION_SHORT = KONG_VERSION.replaceAll('[.]', '').substring(0,2)
                    if(KONG_VERSION >= '3') {
                        // sh 'curl https://packages.konghq.com/public/gateway-$(echo ${KONG_VERSION} | tr -d '.' | cut -c 1-2})/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_${KONG_VERSION}/kong-enterprise-edition_${KONG_VERSION}_amd64.deb -o kong-enterprise-edition-${KONG_VERSION}.deb'
                        sh 'curl https://packages.konghq.com/public/gateway-${KONG_VERSION_SHORT}/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_${KONG_VERSION}/kong-enterprise-edition_${KONG_VERSION}_amd64.deb -o kong-enterprise-edition-${KONG_VERSION}.deb'
                    } else {
                        // sh 'curl https://packages.konghq.com/public/gateway-$(echo ${KONG_VERSION} | tr -d '.' | cut -c 1-2})/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_${KONG_VERSION}/kong-enterprise-edition_${KONG_VERSION}_all.deb -o kong-enterprise-edition-${KONG_VERSION}.deb'
                        sh 'curl https://packages.konghq.com/public/gateway-${KONG_VERSION_SHORT}/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_${KONG_VERSION}/kong-enterprise-edition_${KONG_VERSION}_all.deb -o kong-enterprise-edition-${KONG_VERSION}.deb'
                    }
                    sh 'docker build --tag kong:${APP_VERSION} --build-arg KONG_VERSION=${KONG_VERSION}'
                }
            }
        }

        stage('Scan image with Clair') {
            when {
                expression {
                    BRANCH_NAME == 'main'
                }
            }
            steps {
                script {
                    sh '''
                    docker run -d --name clair-db arminc/clair-db:latest
                    sleep 15
                    docker run -p 6060:6060 --link clair-db:postgres -d --name clair arminc/clair-local-scan:latest
                    sleep 5
                    DOCKER_GATEWAY=$(docker network inspect bridge | jq --raw-output '.[].IPAM.Config[].Gateway')
                    curl https://github.com/arminc/clair-scanner/releases/download/v8/clair-scanner_linux_amd64 -o clair-scanner
                    chmod +x clair-scanner
                    ./clair-scanner --ip="$DOCKER_GATEWAY" --report="${APP_VERSION}" kong:${APP_VERSION} || exit 0
                    '''
                }
                archiveArtifacts (artifacts: '${APP_VERSION}.json')
            }
        }

        stage('Login to registry') {
            when {
                expression {
                    BRANCH_NAME == 'main'
                }
            }
            steps {
                script {
                    echo 'Logging into Docker Hub'
                    withCredentials([usernamePassword(credentialsId: 'docker-hub', passwordVariable: 'PASS', usernameVariable: 'USER')]) {
                        sh 'echo $PASS | docker login -u $USER --password-stdin'
                    }
                }
            }
        }

        stage('Push to registry') {
            when {
                expression {
                    BRANCH_NAME == 'main'
                }
            }
            steps {
                script {
                    echo 'Pushing image to registry'
                    sh 'docker push vladsanyuk/kong:${APP_VERSION}'
                }
            }
        }
    }

    post {
        // Clean-up
        always {
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                cleanWhenAborted: true,
                cleanWhenFailure: true,
                cleanWhenSuccess: true,
                cleanWhenUnstable: true
            )
            script {
                sh '''
                echo Stop and remove Clair containers
                docker stop clair-db clair
                docker rm clair-db clair
                echo Clean-up dangling volumes
                docker volume prune --force
                echo Clean-up images
                docker rmi vladsanyuk/kong:${APP_VERSION} arminc/clair-db:latest arminc/clair-local-scan:latest
                '''
            }
        }
    }
}