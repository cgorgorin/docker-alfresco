FROM centos:centos7

MAINTAINER Florian JUDITH <florian.judith.b@gmail.com>

ENV TERM=xterm

# install some necessary/desired RPMs and get updates
RUN yum update -y && \
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y \
        git \
        ant \
        cups-libs \
        dbus-glib \
        fontconfig \
        hostname \
        libICE \
        libSM \
        libXext \
        libXinerama \
        libXrender \
        supervisor \
        xmlstarlet \
        nano \
        ImageMagick \
        ghostscript \
        wget \
        unzip && \
    yum clean all

# install oracle java
COPY assets/install_java.sh /tmp/install_java.sh
RUN /tmp/install_java.sh && \
    rm -f /tmp/install_java.sh

# install alfresco
COPY assets/install_alfresco.sh /tmp/install_alfresco.sh
RUN /tmp/install_alfresco.sh && \
    rm -f /tmp/install_alfresco.sh

# install mysql connector for alfresco
COPY assets/install_mysql_connector.sh /tmp/install_mysql_connector.sh
RUN /tmp/install_mysql_connector.sh && \
    rm -f /tmp/install_mysql_connector.sh

# this is for LDAP configuration
RUN mkdir -p /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap/ldap1/
RUN mkdir -p /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap-ad/ldap1/
COPY assets/ldap-authentication.properties /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap/ldap1/ldap-authentication.properties
COPY assets/ldap-ad-authentication.properties /alfresco/tomcat/shared/classes/alfresco/extension/subsystems/Authentication/ldap-ad/ldap1/ldap-ad-authentication.properties

# Copy ManualManager Add-On
# Markdown manual editor and viewer
# https://github.com/loftuxab/manual-manager
COPY assets/install_manualmanager.sh /tmp/
RUN chmod +x /tmp/install_manualmanager.sh

# Copy BeCPG Add-On.
# http://www.becpg.fr/
COPY assets/install_becpg.sh /tmp/
RUN chmod +x /tmp/install_becpg.sh

# Copy Markdown Preview Add-On.
# https://github.com/cetra3/md-preview
COPY assets/install_md-preview.sh /tmp/
RUN chmod +x /tmp/install_md-preview.sh

# install scripts
COPY docker-entrypoint.sh /alfresco/
RUN chmod +x /alfresco/docker-entrypoint.sh 
COPY supervisord.conf /etc/

RUN mkdir -p /alfresco/tomcat/webapps/ROOT
COPY assets/index.jsp /alfresco/tomcat/webapps/ROOT/

VOLUME /alfresco/alf_data
VOLUME /alfresco/tomcat/logs

EXPOSE 21 137 138 139 445 8009 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord","-c","/etc/supervisord.conf","-n"]