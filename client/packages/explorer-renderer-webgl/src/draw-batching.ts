import { DRAW_PASS_ORDER, SHADER_KEYS, type DrawPass } from "./render-constants.js";

export interface DrawCommand {
  pass: DrawPass;
  key: string;
  symbol: string;
}

export interface DrawBatch {
  pass: DrawPass;
  shaderKey: string;
  symbol: string;
  commands: DrawCommand[];
}

export function batchDrawCommands(commands: DrawCommand[]): DrawBatch[] {
  const ordered = [...commands].sort(compareDrawCommands);
  const batches: DrawBatch[] = [];

  for (const command of ordered) {
    const shaderKey = SHADER_KEYS[command.pass];
    const lastBatch = batches[batches.length - 1];
    if (
      lastBatch &&
      lastBatch.pass === command.pass &&
      lastBatch.shaderKey === shaderKey &&
      lastBatch.symbol === command.symbol
    ) {
      lastBatch.commands.push(command);
      continue;
    }

    batches.push({
      pass: command.pass,
      shaderKey,
      symbol: command.symbol,
      commands: [command]
    });
  }

  return batches;
}

function compareDrawCommands(a: DrawCommand, b: DrawCommand): number {
  const passDiff = passOrder(a.pass) - passOrder(b.pass);
  if (passDiff !== 0) {
    return passDiff;
  }

  return a.key.localeCompare(b.key);
}

function passOrder(pass: DrawPass): number {
  const index = DRAW_PASS_ORDER.indexOf(pass);
  return index < 0 ? Number.MAX_SAFE_INTEGER : index;
}
