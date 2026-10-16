import { parse } from "yaml";
import swaggerRaw from "../../../api/swagger/v1/swagger.yaml?raw";

// Builds a response body from the API's own OpenAPI schema, so a web component is exercised with the
// field names the API really sends - not with a hand-written fixture that can drift from it.
type Schema = {
  $ref?: string;
  allOf?: Schema[];
  type?: string;
  enum?: unknown[];
  example?: unknown;
  properties?: Record<string, Schema>;
  items?: Schema;
  nullable?: boolean;
};

const doc = parse(swaggerRaw) as { components: { schemas: Record<string, Schema> } };

function resolve(schema: Schema): Schema {
  if (schema.$ref) {
    const name = schema.$ref.split("/").pop() as string;
    return resolve(doc.components.schemas[name]);
  }
  if (schema.allOf) {
    return schema.allOf.map(resolve).reduce<Schema>(
      (acc, s) => ({ ...acc, ...s, properties: { ...acc.properties, ...s.properties } }),
      { type: "object", properties: {} }
    );
  }
  return schema;
}

export function sample(schema: Schema): unknown {
  const s = resolve(schema);
  if (s.example !== undefined) return s.example;
  if (s.enum) return s.enum.find((v) => v !== null);
  switch (s.type) {
    case "object":
      return Object.fromEntries(Object.entries(s.properties ?? {}).map(([k, v]) => [k, sample(v)]));
    case "array":
      return [sample(s.items as Schema)];
    case "integer":
      return 1;
    case "boolean":
      return true;
    default:
      return "x";
  }
}

export function sampleOf(schemaName: string): Record<string, unknown> {
  return sample({ $ref: `#/components/schemas/${schemaName}` }) as Record<string, unknown>;
}
