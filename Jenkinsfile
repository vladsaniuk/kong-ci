#!/usr/bin/env groovy

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
            environment {
                KONG_VERSION_SHORT = KONG_VERSION.replaceAll('[.]', '').substring(0,2)
            }
            steps {
                script {
                    if(KONG_VERSION >= '3') {
                        sh 'curl https://packages.konghq.com/public/gateway-${KONG_VERSION_SHORT}/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_${KONG_VERSION}/kong-enterprise-edition_${KONG_VERSION}_amd64.deb --output kong-enterprise-edition-${KONG_VERSION}.deb'
                    } else {
                        sh 'curl https://packages.konghq.com/public/gateway-${KONG_VERSION_SHORT}/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_${KONG_VERSION}/kong-enterprise-edition_${KONG_VERSION}_all.deb --output kong-enterprise-edition-${KONG_VERSION}.deb'
                    }
                    sh 'docker build --tag vladsanyuk/kong:${APP_VERSION} --build-arg KONG_VERSION=${KONG_VERSION} .'
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
                    // sh '''
                    // docker run -d --name clair-db arminc/clair-db:latest
                    // sleep 15
                    // docker run -p 6060:6060 --link clair-db:postgres -d --name clair arminc/clair-local-scan:latest
                    // sleep 5
                    // # DOCKER_GATEWAY=$(docker network inspect bridge | jq --raw-output '.[].IPAM.Config[].Gateway')
                    // # HOST_IP=$(ifconfig eth0 | grep -Po 'inet \\K[\\d]{1,3}.[\\d]{1,3}.[\\d]{1,3}.[\\d]{1,3}')
                    // curl https://github.com/arminc/clair-scanner/releases/download/v8/clair-scanner_linux_amd64 --location --output clair-scanner
                    // chmod +x clair-scanner
                    // ./clair-scanner --ip="172.17.0.1" --report="report-${APP_VERSION}.json" vladsanyuk/kong:${APP_VERSION} || echo Vulnerabilities found, please, refer to scan report
                    // '''
                    sh '''
                    docker network create scanning
                    docker run -p 5432:5432 -d --net=scanning --name db arminc/clair-db:latest
                    docker run -p 6060:6060  --net=scanning --link db:postgres -d --name clair arminc/clair-local-scan:latest
                    docker run --net=scanning --name=scanner --link=clair:clair -v '/var/run/docker.sock:/var/run/docker.sock'  objectiflibre/clair-scanner --clair="http://clair:6060" --ip="scanner" --report="report-${APP_VERSION}.json" vladsanyuk/kong:${APP_VERSION}
                    docker container cp scanner:report-${APP_VERSION}.json ./report-${APP_VERSION}.json
                    '''
                }
                archiveArtifacts (artifacts: 'report-*.json')
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
                // sh '''
                // echo Stop and remove Clair containers
                // docker stop clair-db clair
                // docker rm clair-db clair
                // echo Clean-up Clair DB image
                // ./clean_up_clair_db.sh
                // echo Clean-up dangling volumes
                // docker volume prune --force
                // echo Clean-up images
                // docker rmi vladsanyuk/kong:${APP_VERSION} arminc/clair-local-scan:latest
                // '''
                echo 'Stop and remove Clair containers'
                try {
                    sh 'docker stop scanner clair-db clair && docker rm scanner clair-db clair'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up Clair DB image'
                try {
                    sh './clean_up_clair_db.sh'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up images'
                try {
                    sh 'docker rmi vladsanyuk/kong:${APP_VERSION} arminc/clair-local-scan:latest objectiflibre/clair-scanner'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up dangling volumes'
                sh 'docker volume prune --force'
            }
        }
    }
}