ARG MP_VERSION=latest
ARG MP_DIR=/opt/midpoint
ARG MP_DIST_FILE=midpoint-dist.tar.gz
ARG SKIP_DOWNLOAD=0
ARG maintainer=evolveum
ARG imagename=midpoint

### values for Ubuntu based image ###
ARG base_image=ubuntu
ARG base_image_tag=18.04
ARG java_home=/usr/lib/jvm/java-11-openjdk-amd64
####################################

### values for Alpine based image ###
# ARG base_image=alpine
# ARG base_image_tag=latest
# ARG java_home=/usr/lib/jvm/default-jvm
#####################################

FROM ${base_image}:${base_image_tag}

ARG base_image
ARG MP_VERSION
ARG MP_DIR
ARG MP_DIST_FILE
ARG SKIP_DOWNLOAD

RUN if [ "${base_image}" = "alpine" ]; \
  then apk --update add --no-cache libxml2-utils curl bash ; \
  else apt-get update -y && apt-get install -y curl libxml2-utils ; \
  fi

COPY download-midpoint common.bash ${MP_DIST_FILE}* ${MP_DIR}/

RUN if [ "${SKIP_DOWNLOAD}" = "0" ]; \
  then chmod 755 ${MP_DIR}/download-midpoint && \
       ${MP_DIR}/download-midpoint ${MP_VERSION} ${MP_DIST_FILE} ; \
  fi ; \
  tar -xzC ${MP_DIR} -f ${MP_DIR}/${MP_DIST_FILE} --strip-components=1 ; \
  rm -f ${MP_DIR}/${MP_DIST_FILE}* ${MP_DIR}/download-midpoint ${MP_DIR}/common.bash

FROM ${base_image}:${base_image_tag}

ARG MP_DIR
ARG MP_VERSION
ARG base_image
ARG base_image_tag
ARG maintainer
ARG imagename

LABEL Vendor="${maintainer}"
LABEL ImageType="base"
LABEL ImageName="${imagename}"
LABEL ImageOS="${base_image}:${base_image_tag}"
LABEL Version="${MP_VERSION}"
LABEL org.opencontainers.image.authors="info@evolveum.com"

ENV JAVA_HOME=${java_home} \
 REPO_DATABASE_TYPE=h2 \
 REPO_JDBC_URL=default \
 REPO_HOST=localhost \
 REPO_PORT=default \
 REPO_DATABASE=midpoint \
 REPO_MISSING_SCHEMA_ACTION=create \
 REPO_UPGRADEABLE_SCHEMA_ACTION=stop \
 MP_MEM_MAX=2048m \
 MP_MEM_INIT=1024m \
 TZ=UTC \
 MP_DIR=${MP_DIR} \
 JAVA_OPTS="-Dmidpoint.repository.hibernateHbm2ddl=none -Dmidpoint.repository.initializationFailTimeout=60000 -Dfile.encoding=UTF8 -Dmidpoint.logging.alt.enabled=true"

COPY container_files/usr-local-bin/* /usr/local/bin/
COPY container_files/mp-dir/ ${MP_DIR}/

RUN if [ "${base_image}" = "alpine" ]; \
  then apk --update add --no-cache openjdk11-jre-headless curl libxml2-utils tzdata bash ; \
  else sed 's/main$/main universe/' -i /etc/apt/sources.list && \
       apt-get update -y && \
       apt-get install -y openjdk-11-jre tzdata && \
       apt-get clean && \
       rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* ; \
  fi ; \
  chmod 755 /usr/local/bin/*.sh /opt/midpoint/repository-url

VOLUME ${MP_DIR}/var

HEALTHCHECK --interval=1m --timeout=30s --start-period=2m CMD /usr/local/bin/healthcheck.sh

EXPOSE 8080

CMD ["/usr/local/bin/midpoint-dirs-docker-entrypoint.sh"]

COPY --from=0 ${MP_DIR} ${MP_DIR}/

