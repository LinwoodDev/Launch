/// <reference path="../.astro/types.d.ts" />

interface ImportMetaEnv {
  readonly APP_NAME?: string;
  readonly APP_LAUNCH_URL?: string;
  readonly APP_DOWNLOAD_URL: string;
  readonly APP_WEB_URL?: string;
  readonly APP_WEB_PREVIEW_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
