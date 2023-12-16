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
                    // We're running Jenkins in container, so using Docker agens is tricky
                    // instead we use Docker besides Docker directly mounting Jenkins volume into luacheck container
                    sh '''
                    docker build --tag alpine-luacheck:latest luacheck
                    docker run --volumes-from jenkins --env WORKSPACE=${WORKSPACE} --name luacheck alpine-luacheck:latest
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
                    echo 'Get Kong docker-entrypoint.sh'
                    sh 'curl https://raw.githubusercontent.com/Kong/docker-kong/master/docker-entrypoint.sh -o kong-docker-entrypoint.sh'
                    echo 'Get Kong deb package'
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
                    // For Clair we're mounting Docker sock from the Jenkins host, so we use --volume, not --volumes-from
                    echo 'Ensure Clair Docker network doesn\'t exist'
                    try {
                        sh 'docker network rm scanning'
                    } catch (err) {
                        echo "Failed: ${err}"
                        echo 'Clair Docker network doesn\'t exist'
                    }
                    sh '''
                    docker network create scanning
                    docker run --publish 5432:5432 --net=scanning --detach --name clair-db arminc/clair-db:latest
                    docker run --link clair-db:postgres --publish 6060:6060 --net=scanning --detach --name clair arminc/clair-local-scan:latest
                    docker run --link=clair:clair --net=scanning -v '/var/run/docker.sock:/var/run/docker.sock' --name=scanner objectiflibre/clair-scanner:latest --clair="http://clair:6060" --ip="scanner" --report="report-${APP_VERSION}.json" vladsanyuk/kong:${APP_VERSION}
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
                        sh 'echo ${PASS} | docker login -u ${USER} --password-stdin'
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
                echo 'Stop Clair containers'
                try {
                    sh 'docker stop scanner clair-db clair && docker rm scanner clair-db clair luacheck'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Remove all exited containers'
                try {
                    sh 'docker rm $(docker ps --all --format {{.ID}} --filter status=exited)'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                // Clair DB container is very big to pull it each time, but it's updated daily, so
                // check if container was created more than 1 day ago, if yes - clean it up
                echo 'Clean-up Clair DB image'
                try {
                    sh './clean_up_clair_db.sh'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up images'
                try {
                    sh 'docker rmi vladsanyuk/kong:${APP_VERSION} arminc/clair-local-scan:latest objectiflibre/clair-scanner:latest alpine-luacheck:latest'
                } catch (err) {
                    echo "Failed: ${err}"
                    echo 'Most likely there is no need for clean-up'
                }
                echo 'Clean-up dangling volumes'
                sh 'docker volume prune --force'
                echo 'Clean-up dangling images'
                sh 'docker image prune --force'
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