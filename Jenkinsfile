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
        ansiColor('xterm')
    }
    environment {
        TIMESTAMP = sh(script: 'date +%s',returnStdout: true).trim()
        APP_VERSION = "${KONG_VERSION}-${TIMESTAMP}-${BUILD_ID}"
        AWS_ACCESS_KEY_ID = credentials('aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_access_key')
    }

    stages {
        stage('Scan custom plugin source code with Luacheck') {
            steps {
                script {
                    sh '''
                    docker build --tag alpine-luacheck:latest luacheck
                    docker run --volume "${WORKSPACE}/opt/plugins:/tmp/" alpine-luacheck:latest
                    '''
                }
            }
        }

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
                    sh '''
                    docker network create scanning
                    docker run -p 5432:5432 -d --net=scanning --name clair-db arminc/clair-db:latest
                    docker run -p 6060:6060  --net=scanning --link clair-db:postgres -d --name clair arminc/clair-local-scan:latest
                    docker run --net=scanning --name=scanner --link=clair:clair -v '/var/run/docker.sock:/var/run/docker.sock' objectiflibre/clair-scanner:latest --clair="http://clair:6060" --ip="scanner" --report="report-${APP_VERSION}.json" vladsanyuk/kong:${APP_VERSION}
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
            script {
                echo 'Stop and remove Clair containers'
                try {
                    sh 'docker stop scanner clair-db clair && docker rm scanner clair-db clair'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                // Clair DB container is very big to pull it each time, but it's updated daily
                echo 'Clean-up Clair DB image'
                try {
                    sh './clean_up_clair_db.sh'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up images'
                try {
                    sh 'docker rmi vladsanyuk/kong:${APP_VERSION} arminc/clair-local-scan:latest objectiflibre/clair-scanner:latest'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up dangling volumes'
                sh 'docker volume prune --force'
                echo 'Remove Clair Docker network'
                try {
                    sh 'docker network rm scanning'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely network wasn\'t created'
                }
            }
            cleanWs(
                cleanWhenNotBuilt: false,
                deleteDirs: true,
                cleanWhenAborted: true,
                cleanWhenFailure: true,
                cleanWhenSuccess: true,
                cleanWhenUnstable: true
            )
        }
    }
}