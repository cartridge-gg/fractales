import type { ToriiViewsManifest, ViewDefinition } from "./manifest.js";

export interface SchemaParityResult {
  ok: boolean;
  missing: string[];
}

export function checkSchemaParity(
  manifest: ToriiViewsManifest,
  availableModelFields: Set<string>
): SchemaParityResult {
  const required = manifest.views.flatMap((view: ViewDefinition) => view.requiredModelFields);
  const missing = required.filter((field) => !availableModelFields.has(field));

  return {
    ok: missing.length === 0,
    missing
  };
}
