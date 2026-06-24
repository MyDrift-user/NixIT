# svgmdl-pape-01 — Paperless-ngx

Native `services.paperless` (Redis + workers auto-provisioned). Public URL:
`paper.lua.li`. Local admin login (not OIDC).

## Deploy
1. Secrets: `paperless/admin-password`, `newt/svgmdl-pape-01`.
2. `./scripts/install-host.sh svgmdl-pape-01 root@<ip>` → `deploy .#svgmdl-pape-01`.
3. Log in as `admin` / the sops password.

## "AI" / hands-off (built-in, no extra service)
Paperless's neural classifier auto-assigns tags / correspondents / document types
and retrains nightly. To run essentially hands-off:
- set each Tag / Correspondent / Type **matching algorithm to "Auto"** in the UI,
- correct a handful of documents — it learns from your corrections.
OCR runs on every ingest (`deu+eng`, skips already-text PDFs).

**Ingest:** drop files into the consume dir (`/var/lib/paperless/consume`) or
scan-to-folder there. Recursive + subdir-as-tags + ASN barcodes are enabled.

## LLM features (optional)
Uncomment the `paperless-ai` container block in `default.nix`, add a
`paperless/ai-env` secret (LLM API token), point it at Ollama/OpenAI. Gives
LLM summaries/auto-tagging on top of the built-in classifier.

## Troubleshoot
- `journalctl -u paperless-* -f` (consumer / scheduler / task-queue / web)
