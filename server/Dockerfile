# 그렙 서버 이미지(#176). 빌드 문맥은 저장소 루트다: docker build -f server/Dockerfile .
# 루트가 문맥인 까닭: processResources가 ../db/migrations(ADR-0010)와 ../db/seed(#102 샘플)를 jar에 넣는다.
# 문맥에서 뺄 것은 server/Dockerfile.dockerignore(BuildKit)가 정한다.

FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
# 의존성 층을 먼저 받아 두면 소스만 바뀐 빌드가 빨라진다
COPY server/gradlew server/settings.gradle.kts server/build.gradle.kts server/
COPY server/gradle server/gradle
RUN chmod +x server/gradlew && cd server && ./gradlew --no-daemon -q dependencies > /dev/null
COPY db db
COPY server/src server/src
RUN cd server && ./gradlew --no-daemon -q bootJar -x test

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --system --uid 10001 grep
COPY --from=build /src/server/build/libs/grep-server-*-SNAPSHOT.jar /app/grep-server.jar
USER grep
# Render 무료 인스턴스 512MB 기준. 힙은 컨테이너 메모리의 55%, 나머지는 메타스페이스·코드 캐시·스레드·직접 메모리 몫이다.
# 한 대·적은 요청이라 SerialGC가 가장 적게 쓴다. 메모리가 바닥나면 멈춘 채 두지 않고 내려서 재시작되게 한다.
# 값을 바꾸려면 실행 때 JAVA_TOOL_OPTIONS를 덮어쓴다.
ENV JAVA_TOOL_OPTIONS="-XX:+UseSerialGC -XX:MaxRAMPercentage=55 -XX:MaxMetaspaceSize=160m -XX:ReservedCodeCacheSize=64m -Xss512k -XX:+ExitOnOutOfMemoryError"
# 포트와 비밀값은 모두 환경변수로 받는다(ADR-0011). PORT를 주지 않으면 8080
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/grep-server.jar"]
