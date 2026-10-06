FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/TaskLite.Web/TaskLite.Web.csproj src/TaskLite.Web/
RUN dotnet restore src/TaskLite.Web/TaskLite.Web.csproj
COPY src/TaskLite.Web/ src/TaskLite.Web/
RUN dotnet publish src/TaskLite.Web/TaskLite.Web.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080
ENTRYPOINT ["dotnet", "TaskLite.Web.dll"]
