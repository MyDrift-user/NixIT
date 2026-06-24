# Paperless-ngx (document management) — native NixOS module. Provisions Redis +
# its workers automatically. "AI" here = the built-in neural classifier that
# auto-assigns tags / correspondents / document types and retrains on your
# corrections — fully automatic once a handful of docs are tagged. OCR runs on
# ingest. For LLM-grade features, add the optional `paperless-ai` companion
# (note at the bottom).
#
# Secret (sops secrets/common.yaml): paperless/admin-password
{ config, ... }:
let
  serviceDomain = config.nixit.serviceDomain;
in {
  sops.secrets."paperless/admin-password".sopsFile = ../../../secrets/common.yaml;

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    port = 28981;
    passwordFile = config.sops.secrets."paperless/admin-password".path;
    settings = {
      PAPERLESS_URL = "https://paper.${serviceDomain}";
      PAPERLESS_TIME_ZONE = "Europe/Zurich";
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_MODE = "skip";                 # don't re-OCR already-text PDFs
      # Hands-off ingestion + automatic classification:
      PAPERLESS_CONSUMER_RECURSIVE = true;
      PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;
      PAPERLESS_CONSUMER_ENABLE_BARCODES = true;
      PAPERLESS_CONSUMER_ENABLE_ASN_BARCODE = true;
      PAPERLESS_TASK_WORKERS = 2;
      PAPERLESS_NUMBER_OF_SUGGESTED_DATES = 5;
    };
  };

  networking.firewall.allowedTCPPorts = [ 28981 ];

  # LLM auto-summaries/auto-tagging beyond the built-in classifier: run the
  # `paperless-ai` container against this instance + an LLM (Ollama/OpenAI):
  #   virtualisation.oci-containers.containers.paperless-ai = {
  #     image = "clusterzx/paperless-ai:latest";
  #     ports = [ "127.0.0.1:3000:3000" ];
  #     environment.PAPERLESS_API_URL = "http://localhost:28981/api";
  #     environmentFiles = [ config.sops.secrets."paperless/ai-env".path ]; # API tokens
  #   };
}
