from fastapi import FastAPI
from app.api.v1.results import router as results_router
from app.api.v1.fleet import router as fleet_router
from app.api.v1.imports import router as imports_router

app = FastAPI(title="MTE Oil Lab API", version="1.0.0")

@app.get("/health")
async def health():
    return {"ok": True}

app.include_router(results_router)
app.include_router(fleet_router)
app.include_router(imports_router)
