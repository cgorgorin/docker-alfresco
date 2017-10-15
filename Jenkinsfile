// 
// https://github.com/jenkinsci/pipeline-model-definition-plugin/wiki/Syntax-Reference
// https://jenkins.io/doc/book/pipeline/syntax/#parallel
// https://jenkins.io/doc/book/pipeline/syntax/#post
pipeline {
    agent any
    environment {
        REPO = 'fjudith/alfresco'
        PRIVATE_REPO = "${PRIVATE_REGISTRY}/${REPO}"
        DOCKER_PRIVATE = credentials('docker-private-registry')
    }
    stages {
        stage ('Checkout') {
            steps {
                script {
                    COMMIT = "${GIT_COMMIT.substring(0,8)}"

                    if ("${BRANCH_NAME}" == "master"){
                        TAG = "latest"
                        ALF_OOO = "libreoffice"
                        ALF_REPO = "repository"
                        ALF_SHA = "share"
                        ALF_SEARCH = "search"
                    }
                    else {
                        TAG = "${BRANCH_NAME}"
                        ALF_OOO = "${BRANCH_NAME}-libreoffice"
                        ALF_REPO = "${BRANCH_NAME}-repository"
                        ALF_SHA = "${BRANCH_NAME}-share"
                        ALF_SEARCH = "${BRANCH_NAME}-search"                        
                    }
                }
                sh 'printenv'
            }
        }
        stage ('Build Alfresco add-ons'){
            parallel {
                stage ("Build Manual Manager add-on"){
                    agent { label 'maven' }
                    steps {
                        git url: 'git://github.com/loftuxab/manual-manager.git',
                            branch: 'master'
                        sh 'tree -sh'
                        sh 'ant package'
                        stash name: 'manual-manager',
                            includes: 'build/dist/**'
                    }
                }
                stage ("Build Markdown Preview add-on"){
                    agent { label 'maven' }
                    steps {
                        // https://bitbucket.org/parashift/alfresco-amp-plugin
                        git url: 'git://github.com/yeyan/alfresco-amp-plugin.git',
                            branch: 'master'
                        sh 'tree -sh'
                        sh 'gradle publish'
                        git url: 'git://github.com/fjudith/md-preview.git',
                            branch: '1.7.2'
                        sh 'tree -sh'
                        sh 'cd share/ && gradle amp && cd ../'
                        sh 'cd repo/ && gradle amp && cd ../'
                        stash name: 'md-preview',
                            includes: 'repo/build/amp/**,share/build/amp/**'
                    }
                }
            }
        }
        stage ('Docker build'){
            stage ('Alfresco Web & Application server') {
                agent { label 'docker'}
                steps {
                    unstash 'manual-manager'
                    unstash 'md-preview'
                    sh 'tree -sh'
                    sh "docker build -f slim/Dockerfile -t ${REPO}:${COMMIT} slim/"
                    sh "docker run -d --name 'alfresco-${BUILD_NUMBER}' -p 55080:8080 -p 55443:8443 ${REPO}:${COMMIT}"
                    sh "docker ps -a"
                    sleep 300
                    sh "docker logs alfresco-${BUILD_NUMBER}"
                    sh 'docker run --rm --link alfresco-${BUILD_NUMBER}:alfresco blitznote/debootstrap-amd64:17.04 bash -c "curl -i -X GET -u admin:admin http://alfresco:8080/alfresco/service/api/audit/control"'
                }
                post {
                    always {
                       sh 'docker rm -f alfresco-${BUILD_NUMBER}'
                    }
                    success {
                        echo 'Tag and Push to private registry'
                        sh "docker tag ${REPO}:${COMMIT} ${REPO}:${TAG}"
                        sh "docker tag ${REPO}:${COMMIT} ${PRIVATE_REPO}:${TAG}"
                        sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                        sh "docker push ${PRIVATE_REPO}:${TAG}"
                    }
                }
            }
        }
        stage ('Docker build Micro-Service'){
            parallel {
                stage ('Alfresco LibreOffice') {
                    agent { label 'docker'}
                    steps {
                        sh 'tree -sh'
                        sh "docker build -f libreoffice/Dockerfile -t ${REPO}:${COMMIT}-libreoffice libreoffice/"
                        sh "docker run -d --name 'libreoffice-${BUILD_NUMBER}' -p 56082:8100 ${REPO}:${COMMIT}-libreoffice"
                        sh "docker ps -a"
                        sleep 300
                        sh "docker logs libreoffice-${BUILD_NUMBER}"
                        sh 'docker exec libreoffice-${BUILD_NUMBER} /bin/bash -c "nc -zv -w 5 localhost 8100"'
                    }
                    post {
                        success {
                            echo 'Tag and Push to private registry'
                            sh "docker tag ${REPO}:${COMMIT}-libreoffice ${REPO}:${ALF_OOO}"
                            sh "docker tag ${REPO}:${COMMIT}-libreoffice ${PRIVATE_REPO}:${ALF_OOO}"
                            sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                            sh "docker push ${PRIVATE_REPO}:${ALF_OOO}"
                        }
                    }
                }
                stage ('Alfresco Search Services') {
                    agent { label 'docker'}
                    steps {
                        sh 'tree -sh'
                        sh "docker build -f search/Dockerfile -t ${REPO}:${COMMIT}-search search/"
                        sh "docker run -d --name 'search-${BUILD_NUMBER}' -p 56082:8100 ${REPO}:${COMMIT}-search"
                        sh "docker ps -a"
                        sleep 300
                        sh "docker logs search-${BUILD_NUMBER}"
                        sh 'docker run --rm --link search-${BUILD_NUMBER}:search blitznote/debootstrap-amd64:17.04 bash -c "curl -i -X GET http://search:8983/solr/admin/cores"'
                    }
                    post {
                        success {
                            echo 'Tag and Push to private registry'
                            sh "docker tag ${REPO}:${COMMIT}-search ${REPO}:${ALF_SEARCH}"
                            sh "docker tag ${REPO}:${COMMIT}-search ${PRIVATE_REPO}:${ALF_SEARCH}"
                            sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                            sh "docker push ${PRIVATE_REPO}:${ALF_SEARCH}"
                        }
                    }
                }
                stage ('Alfresco Content Repository Services') {
                    agent { label 'docker'}
                    steps {
                        unstash 'manual-manager'
                        unstash 'md-preview'
                        sh 'tree -sh'
                        sh "docker build -f repository/Dockerfile -t ${REPO}:${COMMIT}-repository repository/"
                        sh "docker run -d --name 'postgres-${BUILD_NUMBER}' -e POSTGRES_USER=alfresco -e POSTGRES_PASSWORD=alfresco -POSTGRES_DB=alfresco amd64/postgres:9.4"
                        sh "docker run -d --name 'repository-${BUILD_NUMBER}' --link postgres-${BUILD_NUMBER}:postgres --link libreoffice-${BUILD_NUMBER}:libreoffice --link search-${BUILD_NUMBER}:search -p 56080:8080 -p 56443:8443 ${REPO}:${COMMIT}-repository"
                        sh "docker ps -a"
                        sleep 30
                        sh "docker logs repository-${BUILD_NUMBER}"
                        sh "docker run --rm --link repository-${BUILD_NUMBER}:repository blitznote/debootstrap-amd64:17.04 bash -c \"curl -i -X GET -u admin:admin http://repository:8080/alfresco/service/api/audit/control\""
                    }
                    post {
                        success {
                            echo 'Tag and Push to private registry'
                            sh "docker tag ${REPO}:${COMMIT}-repository ${REPO}:${ALF_REPO}"
                            sh "docker tag ${REPO}:${COMMIT}-repository ${PRIVATE_REPO}:${ALF_REPO}"
                            sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                            sh "docker push ${PRIVATE_REPO}:${ALF_REPO}"
                        }
                    }
                }
                stage ('Alfresco Share') {
                    agent { label 'docker'}
                    steps {
                        unstash 'manual-manager'
                        unstash 'md-preview'
                        sh 'tree -sh'
                        sh "docker build -f share/Dockerfile -t ${REPO}:${COMMIT}-share share/"
                        sh "docker run -d --name 'share-${BUILD_NUMBER}' --link repository-${BUILD_NUMBER}:repository ${REPO}:${COMMIT}-share"
                        sh "docker ps -a"
                        sleep 300
                        sh "docker logs share-${BUILD_NUMBER}"
                        sh 'docker run --rm --link share-${BUILD_NUMBER}:share blitznote/debootstrap-amd64:17.04 bash -c "curl -i -X GET -u admin:admin http://share:8080/share/page"'
                    }
                    post {
                        success {
                            echo 'Tag and Push to private registry'
                            sh "docker tag ${REPO}:${COMMIT}-share ${REPO}:${ALF_SHA}"
                            sh "docker tag ${REPO}:${COMMIT}-share ${PRIVATE_REPO}:${ALF_SHA}"
                            sh "docker login -u ${DOCKER_PRIVATE_USR} -p ${DOCKER_PRIVATE_PSW} ${PRIVATE_REGISTRY}"
                            sh "docker push ${PRIVATE_REPO}"
                        }
                    }
                }
                post {
                    always {
                        sh 'docker rm -f search-${BUILD_NUMBER}'
                        sh 'docker rm -f libreoffice-${BUILD_NUMBER}'
                        sh 'docker rm -f repository-${BUILD_NUMBER}'
                        sh 'docker rm -f share-${BUILD_NUMBER}'
                    }
                }
            }
        }
    }
    post {
        always {
            echo 'Run regardless of the completion status of the Pipeline run.'
            sh 'docker rm -f postgres-${BUILD_NUMBER}'
            
        }
        changed {
            echo 'Only run if the current Pipeline run has a different status from the previously completed Pipeline.'
        }
        success {
            echo 'Only run if the current Pipeline has a "success" status, typically denoted in the web UI with a blue or green indication.'
            archive "**/*"
        }
        unstable {
            echo 'Only run if the current Pipeline has an "unstable" status, usually caused by test failures, code violations, etc. Typically denoted in the web UI with a yellow indication.'
        }
        aborted {
            echo 'Only run if the current Pipeline has an "aborted" status, usually due to the Pipeline being manually aborted. Typically denoted in the web UI with a gray indication.'
        }
    }
}