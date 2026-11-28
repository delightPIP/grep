# 그렙 서버 이미지(#176). 빌드 문맥은 저장소 루트다: docker build -f server/Dockerfile .
# 루트가 문맥인 까닭: processResources가 ../db/migrations(ADR-0010)와 ../db/seed(#102 샘플)를 jar에 넣는다.
# 문맥에서 뺄 것은 server/Dockerfile.dockerignore(BuildKit)가 정한다.

# 웹(ADR-0016): Swift Wasm 브리지 → Vite 빌드. 결과(web/dist)를 서버가 정적 파일로 내보낸다.
# Wasm SDK 경로·체크섬은 CI web 잡(.github/workflows/ci.yml)과 같다.
FROM swift:6.4.2 AS wasm
# swift 6.4.2는 설치를 마친 뒤 내려갈 때 가끔 죽는다(URLSession 정리 중). 종료 코드 대신 설치 목록으로 확인한다.
RUN (swift sdk install     https://download.swift.org/swift-6.4.2-release/wasm-sdk/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE_wasm.artifactbundle.tar.gz     --checksum 83baca83553f8c443cda7b84800912e6e709c3acd2e7ebf277794ca5836c0da5 || true)     && swift sdk list | grep -q swift-6.4.2-RELEASE_wasm
# BridgeJS 코드 생성 플러그인이 node를 부른다.
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends nodejs > /dev/null && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY core core
COPY web web
RUN cd web && swift package --swift-sdk swift-6.4.2-RELEASE_wasm js

FROM node:22-bookworm-slim AS web
WORKDIR /src/web
COPY web/package.json web/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY web ./
COPY --from=wasm /src/web/.build/plugins/PackageToJS/outputs/Package .build/plugins/PackageToJS/outputs/Package
# Render는 서비스 환경변수를 빌드 인자로 넘긴다. 서버와 같은 이름의 공개 값(주소·publishable key)을 웹에 넣는다.
# API 주소는 비워 같은 출처로 부른다.
ARG SUPABASE_URL
ARG SUPABASE_PUBLISHABLE_KEY
RUN VITE_SUPABASE_URL="$SUPABASE_URL" VITE_SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY" VITE_API_BASE_URL="" npm run build

FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
# 의존성 층을 먼저 받아 두면 소스만 바뀐 빌드가 빨라진다
COPY server/gradlew server/settings.gradle.kts server/build.gradle.kts server/
COPY server/gradle server/gradle
# 미리 받기는 캐시용이라 실패해도 멈추지 않고 로그 끝만 남긴다. 실제 실패는 아래 bootJar가 원인과 함께 낸다.
RUN chmod +x server/gradlew && cd server     && (./gradlew --no-daemon --console=plain dependencies > /tmp/deps.log 2>&1         || (echo "의존성 미리 받기 실패. bootJar에서 다시 받는다" && tail -n 40 /tmp/deps.log))
COPY db db
COPY server/src server/src
RUN cd server && ./gradlew --no-daemon --console=plain --warning-mode=none bootJar -x test

FROM eclipse-temurin:21-jre
WORKDIR /app
RUN useradd --system --uid 10001 grep
COPY --from=build /src/server/build/libs/grep-server-*-SNAPSHOT.jar /app/grep-server.jar
COPY --from=web /src/web/dist /app/static
# 웹 정적 파일 위치(ADR-0016). 웹을 따로 호스팅하면 이 줄과 위 COPY를 지운다.
ENV SPRING_WEB_RESOURCES_STATIC_LOCATIONS=file:/app/static/
USER grep
# Render 무료 인스턴스 512MB 기준. 힙은 컨테이너 메모리의 55%, 나머지는 메타스페이스·코드 캐시·스레드·직접 메모리 몫이다.
# 한 대·적은 요청이라 SerialGC가 가장 적게 쓴다. 메모리가 바닥나면 멈춘 채 두지 않고 내려서 재시작되게 한다.
# 값을 바꾸려면 실행 때 JAVA_TOOL_OPTIONS를 덮어쓴다.
ENV JAVA_TOOL_OPTIONS="-XX:+UseSerialGC -XX:MaxRAMPercentage=55 -XX:MaxMetaspaceSize=160m -XX:ReservedCodeCacheSize=64m -Xss512k -XX:+ExitOnOutOfMemoryError"
# 포트와 비밀값은 모두 환경변수로 받는다(ADR-0011). PORT를 주지 않으면 8080
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/grep-server.jar"]
