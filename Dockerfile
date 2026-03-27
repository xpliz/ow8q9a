# =============================================================================
# Dockerfile - ServletMirror Java Application
# =============================================================================
# Multi-stage build for optimized production image
# Compatible with Docker and Podman
# =============================================================================

# Stage 1: Build
FROM docker.io/library/maven:3-eclipse-temurin-25 AS builder

RUN git clone --branch r1_3_1 https://github.com/bostjans/javaServletMirror /build
WORKDIR /build

RUN mvn clean package

# Stage 2: Runtime
FROM docker.io/library/eclipse-temurin:25

LABEL maintainer="G" \
      author="bostjans" \
      description="ServletMirror - HTTP Request Mirror (like httpbin)" \
      version="1.3.1"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl iproute2 nano &&\
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/opt/java/openjdk \
    JAVA_OPTS="-Dsun.security.ssl.allowUnsafeRenegotiation=true -Djetty.home=. -Xms256m -Xmx396m -server"

WORKDIR /app

COPY --from=builder /build/target/servletMirror.war ./servletMirror.war
COPY --from=builder /build/target/dependency/jetty-runner.jar ./jetty-runner.jar
COPY --from=builder /build/jetty-runner.xml .

RUN keytool -genkey -alias jetty -keyalg RSA -keystore jetty.keystore -storepass secret \
  -keypass secret -dname "CN=localhost, ou=DEV, o=Dev404, st=Lj., c=SI" \
  -validity 3650 -ext SAN=dns:localhost

RUN chown -R nobody:nogroup /app

EXPOSE 8080

USER nobody

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar jetty-runner.jar --path / servletMirror.war --config jetty-runner.xml "]