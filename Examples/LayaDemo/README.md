# Local Laya Demo (`laya-demo`)

Demonstrates evaluating strongly-typed `@Generable` schemas against a local `laya-serve` instance speaking `POST /v1/systemone` with zero API keys.

---

## Prerequisites

Start `laya-serve` in another terminal or background process:

```bash
laya-serve
```

*(Or via Docker: `docker run -p 8000:8000 ghcr.io/nandhakishorm/laya:latest`)*

---

## Running the Demo

### Default Sample Evaluation
Run with the built-in urgent billing inquiry:

```bash
swift run laya-demo
```

### Custom State Evaluation
Pass any ticket, inquiry, or document text directly from the command line:

```bash
swift run laya-demo "The app is crashing when opening settings after the latest update."
```

### Custom Port or Hosted Endpoint
Override the default `http://127.0.0.1:8000/v1/systemone` using the `LAYA_ENDPOINT` environment variable:

```bash
LAYA_ENDPOINT="http://127.0.0.1:8770/v1/systemone" swift run laya-demo "Cancel my subscription"
```
