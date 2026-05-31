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
ghcr.io/smartflix/cloudopshub-frontend:latest
ghcr.io/smartflix/cloudopshub-backend:latest
ghcr.io/smartflix/cloudopshub-db:latest
```

The GitHub Actions workflow builds and pushes the same three images to GHCR on pushes to `main` or `staging`.

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

```bash
docker build -t ghcr.io/smartflix/cloudopshub-frontend:latest apps/frontend
docker build -t ghcr.io/smartflix/cloudopshub-backend:latest apps/backend
docker build -t ghcr.io/smartflix/cloudopshub-db:latest apps/db
```

## Push Locally To GHCR

```bash
echo <GITHUB_TOKEN> | docker login ghcr.io -u <GITHUB_USERNAME> --password-stdin
docker push ghcr.io/smartflix/cloudopshub-frontend:latest
docker push ghcr.io/smartflix/cloudopshub-backend:latest
docker push ghcr.io/smartflix/cloudopshub-db:latest
```

## Use Docker Hub Instead

Docker Hub is not required because GHCR is already configured. If you prefer Docker Hub:

1. Create Docker Hub repositories:
   - `<dockerhub-user>/cloudopshub-frontend`
   - `<dockerhub-user>/cloudopshub-backend`
   - `<dockerhub-user>/cloudopshub-db`
2. Change the three Helm values files from `ghcr.io/smartflix/...` to `docker.io/<dockerhub-user>/...`.
3. Change `.github/workflows/ci.yml`:
   - `REGISTRY: docker.io`
   - `IMAGE_NAMESPACE: <dockerhub-user>`
   - login username: `${{ secrets.DOCKERHUB_USERNAME }}`
   - login password: `${{ secrets.DOCKERHUB_TOKEN }}`
4. Add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` in GitHub repository secrets.

## Important Production Notes

- Do not leave `k8s/helm/db/values.yaml` with `postgres.password: change-me` in production.
- Prefer immutable tags such as a Git SHA for production releases instead of `latest`.
- If GHCR packages are private, configure Kubernetes image pull secrets before ArgoCD syncs the apps.
