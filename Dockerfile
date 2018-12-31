FROM circleci/openjdk:8u181-jdk-stretch

# install java 8
#
RUN if grep -q Debian /etc/os-release && grep -q jessie /etc/os-release; then \
    echo "deb http://http.us.debian.org/debian/ jessie-backports main" | sudo tee -a /etc/apt/sources.list \
    && echo "deb-src http://http.us.debian.org/debian/ jessie-backports main" | sudo tee -a /etc/apt/sources.list \
    && sudo apt-get update; sudo apt-get install -y -t jessie-backports openjdk-8-jre openjdk-8-jre-headless openjdk-8-jdk openjdk-8-jdk-headless \
  ; elif grep -q Ubuntu /etc/os-release && grep -q Trusty /etc/os-release; then \
    echo "deb http://ppa.launchpad.net/openjdk-r/ppa/ubuntu trusty main" | sudo tee -a /etc/apt/sources.list \
    && echo "deb-src http://ppa.launchpad.net/openjdk-r/ppa/ubuntu trusty main" | sudo tee -a /etc/apt/sources.list \
    && sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key DA1A4A13543B466853BAF164EB9B1D8886F44E2A \
    && sudo apt-get update; sudo apt-get install -y openjdk-8-jre openjdk-8-jre-headless openjdk-8-jdk openjdk-8-jdk-headless \
  ; else \
    sudo apt-get update; sudo apt-get install -y openjdk-8-jre openjdk-8-jre-headless openjdk-8-jdk openjdk-8-jdk-headless \
  ; fi \
  && sudo apt-get install -y bzip2 libgconf-2-4 # for extracting firefox and running chrome, respectively

# Install Maven Version: 3.6.0
# RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/apache-maven.tar.gz https://www.apache.org/dist/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz && tar xf /tmp/apache-maven.tar.gz -C /opt/ && rm /tmp/apache-maven.tar.gz && ln -s /opt/apache-maven-* /opt/apache-maven && /opt/apache-maven/bin/mvn -version
# Update PATH for Java tools
ENV PATH="/opt/sbt/bin:/opt/apache-maven/bin:/opt/apache-ant/bin:/opt/gradle/bin:$PATH"
RUN mvn -version

# install firefox
#
# RUN FIREFOX_URL="https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US" \
#   && ACTUAL_URL=$(curl -Ls -o /dev/null -w %{url_effective} $FIREFOX_URL) \
#   && curl --silent --show-error --location --fail --retry 3 --output /tmp/firefox.tar.bz2 $ACTUAL_URL \
#   && sudo tar -xvjf /tmp/firefox.tar.bz2 -C /opt \
#   && sudo ln -s /opt/firefox/firefox /usr/local/bin/firefox \
#   && sudo apt-get install -y libgtk3.0-cil-dev libasound2 libasound2 libdbus-glib-1-2 libdbus-1-3 \
#   && rm -rf /tmp/firefox.* \
#   && firefox --version

# install geckodriver

# RUN export GECKODRIVER_LATEST_RELEASE_URL=$(curl https://api.github.com/repos/mozilla/geckodriver/releases/latest | jq -r ".assets[] | select(.name | test(\"linux64\")) | .browser_download_url") \
#      && curl --silent --show-error --location --fail --retry 3 --output /tmp/geckodriver_linux64.tar.gz "$GECKODRIVER_LATEST_RELEASE_URL" \
#      && cd /tmp \
#      && tar xf geckodriver_linux64.tar.gz \
#      && rm -rf geckodriver_linux64.tar.gz \
#      && sudo mv geckodriver /usr/local/bin/geckodriver \
#      && sudo chmod +x /usr/local/bin/geckodriver \
#      && geckodriver --version

# install chrome

# RUN curl --silent --show-error --location --fail --retry 3 --output /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
#       && (sudo dpkg -i /tmp/google-chrome-stable_current_amd64.deb || sudo apt-get -fy install)  \
#       && rm -rf /tmp/google-chrome-stable_current_amd64.deb \
#       && sudo sed -i 's|HERE/chrome"|HERE/chrome" --disable-setuid-sandbox --no-sandbox|g' \
#            "/opt/google/chrome/google-chrome" \
#       && google-chrome --version

# RUN export CHROMEDRIVER_RELEASE=$(curl --location --fail --retry 3 http://chromedriver.storage.googleapis.com/LATEST_RELEASE) \
#       && curl --silent --show-error --location --fail --retry 3 --output /tmp/chromedriver_linux64.zip "http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_RELEASE/chromedriver_linux64.zip" \
#       && cd /tmp \
#       && unzip chromedriver_linux64.zip \
#       && rm -rf chromedriver_linux64.zip \
#       && sudo mv chromedriver /usr/local/bin/chromedriver \
#       && sudo chmod +x /usr/local/bin/chromedriver \
#       && chromedriver --version

# start xvfb automatically to avoid needing to express in circle.yml
ENV DISPLAY :99
RUN printf '#!/bin/sh\nXvfb :99 -screen 0 1280x1024x24 &\nexec "$@"\n' > /tmp/entrypoint \
  && chmod +x /tmp/entrypoint \
        && sudo mv /tmp/entrypoint /docker-entrypoint.sh

# ensure that the build agent doesn't override the entrypoint
LABEL com.circleci.preserve-entrypoint=true

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/sh"]

FROM docker:17.12.0-ce as static-docker-source

FROM debian:stretch
ARG CLOUD_SDK_VERSION=228.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION

COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker
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
google-cloud-sdk-app-engine-python=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-app-engine-python-extras=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-app-engine-java=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-app-engine-go=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-datalab=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-datastore-emulator=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-pubsub-emulator=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-bigtable-emulator=${CLOUD_SDK_VERSION}-0 \
google-cloud-sdk-cbt=${CLOUD_SDK_VERSION}-0 \
kubectl && \
gcloud config set core/disable_usage_reporting true && \
gcloud config set component_manager/disable_update_check true && \
gcloud config set metrics/environment github_docker_image && \
gcloud --version && \
docker --version && kubectl version --client
VOLUME ["/root/.config"]
