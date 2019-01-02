FROM openjdk:8-jdk

# make Apt non-interactive
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90circleci \
  && echo 'DPkg::Options "--force-confnew";' >> /etc/apt/apt.conf.d/90circleci

ENV DEBIAN_FRONTEND=noninteractive

# man directory is missing in some base images
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=863199
RUN apt-get update \
  && mkdir -p /usr/share/man/man1 \
  && apt-get install -y \
    git mercurial xvfb \
    locales sudo openssh-client ca-certificates tar gzip parallel \
    net-tools netcat unzip zip bzip2 gnupg curl wget


# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Use unicode
RUN locale-gen C.UTF-8 || true
ENV LANG=C.UTF-8

## install jq
#RUN JQ_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/jq-latest" \
#  && curl --silent --show-error --location --fail --retry 3 --output /usr/bin/jq $JQ_URL \
#  && chmod +x /usr/bin/jq \
#  && jq --version

# Install Docker

# Docker.com returns the URL of the latest binary when you hit a directory listing
# We curl this URL and `grep` the version out.
# The output looks like this:

#>    # To install, run the following commands as root:
#>    curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-17.05.0-ce.tgz && tar --strip-components=1 -xvzf docker-17.05.0-ce.tgz -C /usr/local/bin
#>
#>    # Then start docker in daemon mode:
#>    /usr/local/bin/dockerd

RUN set -ex \
  && export DOCKER_VERSION=$(curl --silent --fail --retry 3 https://download.docker.com/linux/static/stable/x86_64/ | grep -o -e 'docker-[.0-9]*-ce\.tgz' | sort -r | head -n 1) \
  && DOCKER_URL="https://download.docker.com/linux/static/stable/x86_64/${DOCKER_VERSION}" \
  && echo Docker URL: $DOCKER_URL \
  && curl --silent --show-error --location --fail --retry 3 --output /tmp/docker.tgz "${DOCKER_URL}" \
  && ls -lha /tmp/docker.tgz \
  && tar -xz -C /tmp -f /tmp/docker.tgz \
  && mv /tmp/docker/* /usr/bin \
  && rm -rf /tmp/docker /tmp/docker.tgz \
  && which docker \
  && (docker version || true)
#
## docker compose
RUN COMPOSE_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/docker-compose-latest" \
  && curl --silent --show-error --location --fail --retry 3 --output /usr/bin/docker-compose $COMPOSE_URL \
  && chmod +x /usr/bin/docker-compose \
  && docker-compose version
#
## install dockerize
RUN DOCKERIZE_URL="https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/dockerize-latest.tar.gz" \
  && curl --silent --show-error --location --fail --retry 3 --output /tmp/dockerize-linux-amd64.tar.gz $DOCKERIZE_URL \
  && tar -C /usr/local/bin -xzvf /tmp/dockerize-linux-amd64.tar.gz \
  && rm -rf /tmp/dockerize-linux-amd64.tar.gz \
  && dockerize --version

RUN groupadd --gid 3434 circleci \
  && useradd --uid 3434 --gid circleci --shell /bin/bash --create-home circleci \
  && echo 'circleci ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-circleci \
  && echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

# BEGIN IMAGE CUSTOMIZATIONS

# cacerts from OpenJDK 9-slim to workaround http://bugs.java.com/view_bug.do?bug_id=8189357
# AND https://github.com/docker-library/openjdk/issues/145
#
# Created by running:
# docker run --rm openjdk:9-slim cat /etc/ssl/certs/java/cacerts | #   aws s3 cp - s3://circle-downloads/circleci-images/cache/linux-amd64/openjdk-9-slim-cacerts --acl public-read
RUN if java -fullversion 2>&1 | grep -q '"9.'; then   curl --silent --show-error --location --fail --retry 3 --output /etc/ssl/certs/java/cacerts        https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/openjdk-9-slim-cacerts;  fi
#
## Install Maven Version: 3.5.3
RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/apache-maven.tar.gz     https://www.apache.org/dist/maven/maven-3/3.5.4/binaries/apache-maven-3.5.4-bin.tar.gz   && tar xf /tmp/apache-maven.tar.gz -C /opt/   && rm /tmp/apache-maven.tar.gz   && ln -s /opt/apache-maven-* /opt/apache-maven   && /opt/apache-maven/bin/mvn -version
#
## Install Ant Version: 1.10.2
#RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/apache-ant.tar.gz     https://archive.apache.org/dist/ant/binaries/apache-ant-1.10.2-bin.tar.gz   && tar xf /tmp/apache-ant.tar.gz -C /opt/   && ln -s /opt/apache-ant-* /opt/apache-ant   && rm -rf /tmp/apache-ant.tar.gz   && /opt/apache-ant/bin/ant -version
#
#ENV ANT_HOME=/opt/apache-ant

# Install Gradle Version: 4.6
# RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/gradle.zip     https://services.gradle.org/distributions/gradle-4.6-bin.zip   && unzip -d /opt /tmp/gradle.zip   && rm /tmp/gradle.zip   && ln -s /opt/gradle-* /opt/gradle   && /opt/gradle/bin/gradle -version

# Install sbt from https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/sbt-latest.tgz
# RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/sbt.tgz https://circle-downloads.s3.amazonaws.com/circleci-images/cache/linux-amd64/sbt-latest.tgz   && tar -xzf /tmp/sbt.tgz -C /opt/   && rm /tmp/sbt.tgz   && /opt/sbt/bin/sbt sbtVersion

# Install openjfx
#RUN apt-get install -y --no-install-recommends openjfx

# Update PATH for Java tools
ENV PATH="/opt/sbt/bin:/opt/apache-maven/bin:/opt/apache-ant/bin:/opt/gradle/bin:$PATH"

# smoke test with path
RUN mvn -version
# RUN mvn -version \
#   && ant -version \
#   && gradle -version \
#   && sbt sbtVersion
# END IMAGE CUSTOMIZATIONS

# Download Spring Dependencies
COPY pom.xml .
RUN mvn dependency:resolve dependency:resolve-plugins clean package
COPY . .
VOLUME ["~/.m2"]

# FROM debian:stretch
ARG CLOUD_SDK_VERSION=228.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION

# COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker
RUN apt-get -qqy update && apt-get install -qqy \
curl \
gcc \
python-dev \
python-setuptools \
apt-transport-https \
lsb-release \
openssh-client \
git \
gnupg \
&& easy_install -U pip && \
pip install -U crcmod && \
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
apt-get update && \
apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-app-engine-python=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-app-engine-python-extras=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-app-engine-java=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-app-engine-go=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-datalab=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-datastore-emulator=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-pubsub-emulator=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-bigtable-emulator=${CLOUD_SDK_VERSION}-0 \
#google-cloud-sdk-cbt=${CLOUD_SDK_VERSION}-0 \
kubectl && \
gcloud config set core/disable_usage_reporting true && \
gcloud config set component_manager/disable_update_check true && \
gcloud config set metrics/environment github_docker_image && \
gcloud --version && \
docker --version && kubectl version --client
VOLUME ["/root/.config"]

USER circleci
CMD ["/bin/sh"]