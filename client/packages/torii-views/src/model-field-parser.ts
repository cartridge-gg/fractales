export function extractModelFieldSetFromSource(source: string): Set<string> {
  const result = new Set<string>();
  const interfacePattern = /export interface\s+(\w+)\s*\{([\s\S]*?)\n\}/g;
  let interfaceMatch: RegExpExecArray | null = interfacePattern.exec(source);

  while (interfaceMatch) {
    const modelName = interfaceMatch[1];
    const body = interfaceMatch[2];
    if (!modelName || !body) {
      interfaceMatch = interfacePattern.exec(source);
      continue;
    }
    const fieldPattern = /^\s*([a-zA-Z_][a-zA-Z0-9_]*)\??\s*:/gm;
    let fieldMatch: RegExpExecArray | null = fieldPattern.exec(body);
    while (fieldMatch) {
      const fieldName = fieldMatch[1];
      if (!fieldName) {
        fieldMatch = fieldPattern.exec(body);
        continue;
      }
      result.add(`${modelName}.${fieldName}`);
      fieldMatch = fieldPattern.exec(body);
    }
    interfaceMatch = interfacePattern.exec(source);
  }

  return result;
}
