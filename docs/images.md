# Container Images

This project now has one build folder per deployable image:

| Component | Build folder | Dockerfile | Helm image value |
| --- | --- | --- | --- |
| Frontend | `apps/frontend` | `apps/frontend/Dockerfile` | `k8s/helm/frontend/values.yaml` |
| Backend | `apps/backend` | `apps/backend/Dockerfile` | `k8s/helm/backend/values.yaml` |
| DB | `apps/db` | `apps/db/Dockerfile` | `k8s/helm/db/values.yaml` |

## Current Images

The Helm charts currently deploy these images:

```text
docker.io/fabulousjeff2009/cloudopshub-frontend:latest
docker.io/fabulousjeff2009/cloudopshub-backend:latest
docker.io/fabulousjeff2009/cloudopshub-db:latest
```

The GitHub Actions workflow builds and pushes the same three images to Docker Hub on pushes to `main` or `staging`.

## Replace The Images

1. Put your real frontend build files in `apps/frontend`.
2. Update `apps/frontend/Dockerfile` if your frontend needs a build step.
3. Put your real backend source in `apps/backend`.
4. Update `apps/backend/Dockerfile` for your backend runtime.
5. Keep `apps/db/Dockerfile` only if you need a custom Postgres image with init scripts. If you do not need that, set the DB Helm image back to `postgres:15`.
6. Commit and push to `main` or `staging`.
7. Confirm the workflow publishes the three images.
8. ArgoCD will sync the Helm charts from `k8s/apps`.

## Build Locally

For the application-first local workflow, use Docker Compose:

```powershell
docker compose up --build
```

Then open `http://localhost:18090`.

To build individual images manually:

```bash
docker build -t docker.io/fabulousjeff2009/cloudopshub-frontend:latest apps/frontend
docker build -t docker.io/fabulousjeff2009/cloudopshub-backend:latest apps/backend
docker build -t docker.io/fabulousjeff2009/cloudopshub-db:latest apps/db
```

## Push Locally To Docker Hub

```bash
docker login
docker push docker.io/fabulousjeff2009/cloudopshub-frontend:latest
docker push docker.io/fabulousjeff2009/cloudopshub-backend:latest
docker push docker.io/fabulousjeff2009/cloudopshub-db:latest
```

## Docker Hub CI

The CI workflow is configured for Docker Hub:

1. Create these Docker Hub repositories under `fabulousjeff2009` if they do not exist:
   - `cloudopshub-frontend`
   - `cloudopshub-backend`
   - `cloudopshub-db`
2. Add these GitHub repository secrets:
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN`
3. Push to `main` or `staging`.

## Build And Push To Docker Hub Locally

From a normal PowerShell terminal running as your Windows user:

```powershell
cd C:\Users\Owner\CloudOpsHub\Deployment-of-Multi-Cluster-Infrastructure-Platform-with-Continuous-Delivery-and-Observability
.\scripts\dockerhub-build-push.ps1 -DockerHubUser fabulousjeff2009
```

Use a specific tag when you do not want to push `latest`:

```powershell
.\scripts\dockerhub-build-push.ps1 -DockerHubUser fabulousjeff2009 -Tag v1
```

If you already ran `docker login`, skip the login prompt:

```powershell
.\scripts\dockerhub-build-push.ps1 -DockerHubUser fabulousjeff2009 -SkipLogin
```

## Important Production Notes

- The db chart reads `POSTGRES_PASSWORD` from the Kubernetes Secret named `cloudopshub-db-secret`.
- Prefer immutable tags such as a Git SHA for production releases instead of `latest`.
- If Docker Hub repositories are private, configure Kubernetes image pull secrets before ArgoCD syncs the apps.
