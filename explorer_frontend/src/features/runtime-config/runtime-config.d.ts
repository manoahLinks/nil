// this files enables autocomplete for runtime config values

const keys = [
  "DOCUMENTATION_URL",
  "GITHUB_URL",
  "API_URL",
  "SANDBOX_DOCS_URL",
  "SANDBOX_NILJS_URL",
  "SANDBOX_MULTIToken_URL",
  "SANDBOX_SUPPORT_URL",
  "SANDBOX_FEEDBACK_URL",
  "COMETA_SERVICE_API_URL",
  "RPC_API_URL",
  "API_REQUESTS_ENABLE_BATCHING",
  "RECENT_PROJECTS_STORAGE_LIMIT",
] as const;

type RuntimConfigKeys = (typeof keys)[number];

declare global {
  interface Window {
    RUNTIME_CONFIG: Record<RuntimConfigKeys, string>;
  }
}

export {};
