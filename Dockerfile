COPY --from=google/cloud-sdk:latest
COPY --from=circleci/openjdk:8-jdk-browsers
