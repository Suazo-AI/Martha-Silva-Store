# syntax=docker/dockerfile:1
# SAVIA container images. Build context: the savia/ folder.
#   docker build --target api      -t savia-api      savia    # hub API + static web (default target)
#   docker build --target migrator -t savia-migrator savia    # one-off migration job
# Base images are pinned by digest (SDK 10.0.402 = global.json; runtime 10.0.13 = the SDK's runtime).
# No secrets enter the image: configuration arrives as environment variables at run time.

ARG SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0.402@sha256:747cbade5bfd918a175ac32f8f1d931edec2c7d0d5397a3de72eaef1ac1f66d2
ARG RUNTIME_IMAGE=mcr.microsoft.com/dotnet/aspnet:10.0.13@sha256:8af87eba5e7cdafb1514d7388be287365da97c132509e84dfe252ffd552398ca

FROM ${SDK_IMAGE} AS build
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1
WORKDIR /src
# Restore first from project files and lock files only, so source edits reuse the restore layer.
COPY Directory.Build.props ./
COPY src/Savia.Domain/Savia.Domain.csproj src/Savia.Domain/packages.lock.json src/Savia.Domain/
COPY src/Savia.Contracts/Savia.Contracts.csproj src/Savia.Contracts/packages.lock.json src/Savia.Contracts/
COPY src/Savia.Application/Savia.Application.csproj src/Savia.Application/packages.lock.json src/Savia.Application/
COPY src/Savia.Infrastructure/Savia.Infrastructure.csproj src/Savia.Infrastructure/packages.lock.json src/Savia.Infrastructure/
COPY src/Savia.Api/Savia.Api.csproj src/Savia.Api/packages.lock.json src/Savia.Api/
COPY deploy/migrator/Savia.Migrator.csproj deploy/migrator/packages.lock.json deploy/migrator/
RUN dotnet restore src/Savia.Api/Savia.Api.csproj --locked-mode \
 && dotnet restore deploy/migrator/Savia.Migrator.csproj --locked-mode
COPY src/ src/
COPY deploy/migrator/ deploy/migrator/
# Tests run in CI before this build (savia/tools/check.py and the workflow); publish here is test-free.
RUN dotnet publish src/Savia.Api/Savia.Api.csproj -c Release --no-restore -o /out/api -p:UseAppHost=false \
 && dotnet publish deploy/migrator/Savia.Migrator.csproj -c Release --no-restore -o /out/migrator -p:UseAppHost=false

# One-off migration job: applies savia/db/migrations with the same ledger as saviadb.py.
FROM ${RUNTIME_IMAGE} AS migrator
WORKDIR /app
COPY --from=build /out/migrator ./
COPY db/migrations/ ./migrations/
USER $APP_UID
ENTRYPOINT ["dotnet", "Savia.Migrator.dll"]

# Hub API. Serves the browser client from /app/web. Listens on 8080 as the non-root user "app".
FROM ${RUNTIME_IMAGE} AS api
WORKDIR /app
COPY --from=build /out/api ./
COPY web/ ./web/
ENV ASPNETCORE_HTTP_PORTS=8080 \
    Savia__Web__Root=/app/web \
    DOTNET_CLI_TELEMETRY_OPTOUT=1
EXPOSE 8080
USER $APP_UID
# The runtime image has no curl; bash /dev/tcp checks the same endpoint as the Azure probes.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --start-interval=2s --retries=3 \
  CMD ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/8080 && printf 'GET /health HTTP/1.1\\r\\nHost: localhost\\r\\nConnection: close\\r\\n\\r\\n' >&3 && grep -q '\"status\":\"ok\"' <&3"]
ENTRYPOINT ["dotnet", "Savia.Api.dll"]
