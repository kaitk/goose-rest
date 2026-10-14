// Types for the OpenAPI 3.1 subset that goose-rest gen accepts
// (docs/generator.md), and api(), which checks a document against them while
// it's written. A contract file passes the document to api(), and running it
// with node or bun prints api.json:
//
//   import { api, json } from "./api.mts";
//   const doc = api({ openapi: "3.1.0", info: { title: "Projects", version: "1" }, ... });
//   console.log(json(doc));
//
// api() infers the document's literal types, so tsc also checks what a plain
// type can't: that a $ref names a component, that required names a property,
// and that a path parameter is in its template. The generator stays the check
// for values and names: cycles, identifiers, collisions, and number ranges.
// Task 011 lists which of the two refuses what.

// Annotations, which any schema may carry and the generator ignores.
export type Annotations = {
  description?: string;
  title?: string;
  examples?: readonly unknown[];
  example?: unknown;
  deprecated?: boolean;
  $comment?: string;
};

type Kind = "string" | "integer" | "number" | "boolean" | "object" | "array";
type Nullable<T extends Kind> = T | readonly [T, "null"] | readonly ["null", T];

export type StringFormat = "date" | "date-time" | "uuid" | "email";
export type IntegerFormat = "int32" | "int64";
export type NumberFormat = "float" | "double";

export type StringSchema = Annotations & {
  type: Nullable<"string">;
  minLength?: number;
  maxLength?: number;
  format?: StringFormat;
};
export type EnumSchema = Annotations & { type: Nullable<"string">; enum: readonly [string, ...string[]] };
type Bounds = { minimum?: number; maximum?: number; exclusiveMinimum?: number; exclusiveMaximum?: number };
export type IntegerSchema = Annotations & Bounds & { type: Nullable<"integer">; format?: IntegerFormat };
export type NumberSchema = Annotations & Bounds & { type: Nullable<"number">; format?: NumberFormat };
export type BooleanSchema = Annotations & { type: Nullable<"boolean"> };
export type ObjectSchema = Annotations & {
  type: Nullable<"object">;
  properties: { readonly [name: string]: Schema };
  required?: readonly string[];
  additionalProperties?: boolean;
};
export type ArraySchema = Annotations & {
  type: Nullable<"array">;
  items: Schema;
  minItems?: number;
  maxItems?: number;
};
export type Ref = Annotations & { $ref: `#/components/schemas/${string}` };
export type Schema =
  | StringSchema
  | EnumSchema
  | IntegerSchema
  | NumberSchema
  | BooleanSchema
  | ObjectSchema
  | ArraySchema
  | Ref;

type ParameterAnnotations = { description?: string; deprecated?: boolean; example?: unknown; examples?: unknown };
type IntegerParameterSchema = Annotations & {
  type: "integer";
  minimum?: number;
  maximum?: number;
  format?: IntegerFormat;
};
export type PathParameter = ParameterAnnotations & {
  name: string;
  in: "path";
  required: true;
  schema: IntegerParameterSchema | (Annotations & { type: "string" });
};
export type OtherParameter = ParameterAnnotations & {
  name: string;
  in: "query" | "header" | "cookie";
  required?: boolean;
  schema:
    | IntegerParameterSchema
    | (Annotations & { type: "boolean" })
    | (Annotations & { type: "string"; minLength?: number; maxLength?: number });
};
export type Parameter = PathParameter | OtherParameter;

export type RequestBody = {
  required: true;
  description?: string;
  // The longest body the route takes, in bytes; 1 MB without it.
  "x-body-limit"?: number;
  content: { "application/json": { schema: Ref } };
};
// One requirement of one scheme, without scopes, or none.
export type Security = readonly [] | readonly [{ readonly [scheme: string]: readonly [] }];
// Responses are documentation: the generator reads nothing in them.
export type Response = {
  description: string;
  headers?: { readonly [name: string]: unknown };
  content?: { readonly [media: string]: { schema?: unknown; example?: unknown; examples?: unknown } };
  links?: unknown;
};
export type ExternalDocs = { url: string; description?: string };
export type Operation = {
  operationId: string;
  parameters?: readonly Parameter[];
  requestBody?: RequestBody;
  security?: Security;
  responses?: { readonly [status: string]: Response };
  summary?: string;
  description?: string;
  tags?: readonly string[];
  deprecated?: boolean;
  externalDocs?: ExternalDocs;
};
type Method = "get" | "put" | "post" | "delete" | "options" | "head" | "patch" | "trace";
export type PathItem = { parameters?: readonly Parameter[]; summary?: string; description?: string } & {
  [M in Method]?: Operation;
};
// The generator reads only the type and the name of a scheme; the rest is
// for the handler that checks it.
export type SecurityScheme = { type: "apiKey" | "http" | "mutualTLS" | "oauth2" | "openIdConnect"; [key: string]: unknown };

export type Api = {
  openapi: `3.1.${number}`;
  info: { title: string; version: string; [key: string]: unknown };
  servers?: readonly { url: string; description?: string }[];
  tags?: readonly { name: string; description?: string }[];
  externalDocs?: ExternalDocs;
  security?: Security;
  paths?: { readonly [path: `/${string}`]: PathItem };
  components: {
    schemas: { readonly [name: string]: Schema };
    securitySchemes?: { readonly [name: string]: SecurityScheme };
  };
};

// Checks the document, as written, and returns it with its literal types,
// for a program that reads the document further.
export function api<const D extends CheckApi<D>>(doc: D): D {
  return doc;
}

// The document as JSON, for api.json.
export function json(doc: Api): string {
  return JSON.stringify(doc, null, 2);
}

// The checks. Each maps a part S of the document to the type S must have.
// Where a key or a value is outside the subset, that type is a string literal
// that gives the reason, so tsc's error reads as the generator's would.

// S's keys checked against Spec: each must be one of Spec's, of Spec's type,
// and a required key of Spec must be present.
type Keys<S, Spec, What extends string> = {
  [K in keyof S]: K extends keyof Spec
    ? Spec[K]
    : K extends "nullable"
      ? `nullable is OpenAPI 3.0's; write the type as ["<type>", "null"]`
      : `${K & string} isn't supported on ${What}`;
} & Omit<Spec, keyof S>;

type CheckApi<D> = Keys<
  D,
  Omit<Api, "paths" | "components" | "security"> & {
    components: D extends { components: infer X } ? CheckComponents<X, Components<D>> : Api["components"];
    paths?: D extends { paths: infer P } ? CheckPaths<P, Components<D>, Schemes<D>> : never;
    security?: D extends { security: infer S } ? CheckSecurity<S, Schemes<D>> : never;
  },
  "a document"
>;

type Components<D> = D extends { components: { schemas: infer C } } ? C : {};
type Schemes<D> = D extends { components: { securitySchemes: infer S } } ? keyof S & string : never;

type CheckComponents<X, C> = Keys<
  X,
  { schemas: { [N in keyof C]: CheckSchema<C[N], C, false> }; securitySchemes?: Api["components"]["securitySchemes"] },
  "components"
>;

type KindOf<T> = T extends Kind ? T : T extends readonly [infer A, "null"] | readonly ["null", infer A] ? A : never;

// The type keyword's type for a schema of kind K, inside an array's items or
// not.
type TypeOf<K extends Kind, Item extends boolean> = Item extends true
  ? K | "a nullable element isn't supported"
  : Nullable<K>;

type CheckSchema<S, C, Item extends boolean> = S extends { $ref: unknown }
  ? Keys<S, Annotations & { $ref: RefTo<C, Item> }, "a $ref">
  : S extends { type: infer T }
    ? CheckKind<S, C, Item, KindOf<T>>
    : Keys<S, Annotations & { type: Nullable<Kind> }, "a schema without a type">;

// A $ref names a component; an array's items can't name an array or a
// nullable schema.
type RefTo<C, Item extends boolean> = Item extends true
  ? `#/components/schemas/${ItemNames<C> & string}` | "an array's items can't name an array or a nullable schema"
  : `#/components/schemas/${keyof C & string}`;
type ItemNames<C> = {
  [N in keyof C]: C[N] extends { type: infer T } ? (T extends "array" | readonly unknown[] ? never : N) : N;
}[keyof C];
type ObjectNames<C> = { [N in keyof C]: C[N] extends { type: "object" } ? N : never }[keyof C];

type CheckKind<S, C, Item extends boolean, K> = [K] extends [never]
  ? Keys<S, { type: Nullable<Kind> | "one type besides null is supported" }, "a schema">
  : K extends "string"
    ? S extends { enum: unknown }
      ? Keys<S, Annotations & { type: TypeOf<"string", Item>; enum: EnumSchema["enum"] }, "a string beside enum">
      : Keys<S, Omit<StringSchema, "type"> & { type: TypeOf<"string", Item> }, "a string">
    : K extends "integer"
      ? Keys<S, Omit<IntegerSchema, "type"> & { type: TypeOf<"integer", Item> }, "an integer">
      : K extends "number"
        ? Keys<S, Omit<NumberSchema, "type"> & { type: TypeOf<"number", Item> }, "a number">
        : K extends "boolean"
          ? Keys<S, Annotations & { type: TypeOf<"boolean", Item> }, "a boolean">
          : K extends "object"
            ? CheckObject<S, C, Item>
            : K extends "array"
              ? Item extends true
                ? Keys<S, Omit<ArraySchema, "type"> & { type: "an array of arrays isn't supported" }, "an array">
                : CheckArray<S, C>
              : never;

type CheckObject<S, C, Item extends boolean> = S extends { properties: infer P }
  ? Keys<
      S,
      Omit<ObjectSchema, "type" | "properties" | "required"> & {
        type: TypeOf<"object", Item>;
        properties: { [N in keyof P]: FieldCheck<N & string, CheckSchema<P[N], C, false>> };
        required?: readonly (keyof P & string)[];
      },
      "an object"
    >
  : Keys<S, Omit<ObjectSchema, "type"> & { type: TypeOf<"object", Item> }, "an object">;

type CheckArray<S, C> = S extends { items: infer I }
  ? Keys<S, Omit<ArraySchema, "items"> & { items: CheckSchema<I, C, true> }, "an array">
  : Keys<S, ArraySchema, "an array">;

// The generated reader's own locals, which a field can't be named.
type ReaderName = "r" | "scratch" | "key" | "s_" | "e_" | "ok_" | "n_" | "end_" | "v_" | "x_";
type FieldCheck<N extends string, T> = [Snake<N>] extends [never]
  ? T
  : Snake<N> extends ReaderName
    ? `the field name ${Snake<N>} is one the reader uses`
    : T;

// The name in snake_case as the generator writes it, or never for a name it
// refuses.
type Upper = Uppercase<Lower>;
type Lower = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z";
type Digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9";
type Sep<Out extends string> = Out extends "" | `${string}_` ? "" : "_";
type Snake<S extends string, Prev extends string = "", Out extends string = ""> = S extends `${infer Ch}${infer Rest}`
  ? Ch extends Upper
    ? Snake<
        Rest,
        Ch,
        `${Out}${Prev extends Lower | Digit
          ? Sep<Out>
          : Prev extends Upper
            ? Rest extends `${Lower}${string}`
              ? Sep<Out>
              : ""
            : ""}${Lowercase<Ch>}`
      >
    : Ch extends Lower | Digit | "_"
      ? Snake<Rest, Ch, `${Out}${Ch}`>
      : Ch extends "-" | "." | " "
        ? Snake<Rest, Ch, `${Out}${Sep<Out>}`>
        : never
  : Out;

type AllDigits<S> = S extends `${Digit}${infer R}` ? (R extends "" ? true : AllDigits<R>) : false;
// dispatch's locals, which a path parameter or a handler can't be named.
type DispatchName<N extends string> = [Snake<N>] extends [never]
  ? false
  : Snake<N> extends "cx" | "state" | "path" | "m" | "plain" | "s_" | "q_" | "body_"
    ? true
    : Snake<N> extends `${"s" | "e"}${infer R}`
      ? AllDigits<R>
      : false;
// The parameters reader's locals, which another parameter can't be named.
type ParamsName<N extends string> = [Snake<N>] extends [never] ? false : Snake<N> extends "cx" | "v" | "n_" ? true : false;
type Reserved<N extends string> = `the name ${Snake<N>} is one the generated code uses`;

type CheckPaths<P, C, Schemes extends string> = {
  [T in keyof P]: T extends `/${string}` ? CheckPathItem<P[T], TemplateNames<T>, C, Schemes> : "a path must start with '/'";
};

// The names of a path template's parameters, {name}.
type TemplateNames<T> = T extends `${string}{${infer N}}${infer Rest}` ? N | TemplateNames<Rest> : never;
type Names<L> = L extends readonly (infer E)[] ? (E extends { name: infer N } ? N : never) : never;

type CheckPathItem<I, T extends string, C, Schemes extends string> = Keys<
  I,
  {
    parameters?: CheckParameters<I extends { parameters: infer L } ? L : [], T>;
    summary?: string;
    description?: string;
  } & {
    [M in Method]?: M extends keyof I
      ? CheckOperation<I[M], T, Names<I extends { parameters: infer L } ? L : []>, C, Schemes>
      : never;
  },
  "a path item"
> &
  ([keyof I & Method] extends [never] ? { "a path needs an operation": Operation } : unknown);

type CheckOperation<O, T extends string, Shared, C, Schemes extends string> = Keys<
  O,
  Omit<Operation, "operationId" | "parameters" | "requestBody" | "security"> & {
    operationId: O extends { operationId: infer N extends string } ? (DispatchName<N> extends true ? Reserved<N> : string) : string;
    parameters?: CheckParameters<O extends { parameters: infer L } ? L : [], T>;
    requestBody?: O extends { requestBody: infer B } ? CheckBody<B, C> : never;
    security?: O extends { security: infer S } ? CheckSecurity<S, Schemes> : never;
  },
  "an operation"
> & {
  // Each parameter of the template is declared, by the path item or here.
  [N in Exclude<T, Shared | Names<O extends { parameters: infer L } ? L : []>> as `{${N}}`]: "no parameter declares it";
};

type CheckParameters<L, T extends string> = L extends readonly unknown[]
  ? { [I in keyof L]: CheckParameter<L[I], T> }
  : readonly Parameter[];

type CheckParameter<P, T extends string> = P extends { in: "path"; name: infer N extends string }
  ? Keys<
      P,
      Omit<PathParameter, "name" | "schema"> & {
        name: N extends T ? (DispatchName<N> extends true ? Reserved<N> : N) : T | "a path parameter names one of the path's";
        schema: P extends { schema: infer S } ? CheckPathSchema<S> : PathParameter["schema"];
      },
      "a parameter"
    >
  : P extends { in: "query" | "header" | "cookie"; name: infer N extends string }
    ? Keys<
        P,
        Omit<OtherParameter, "name" | "schema"> & {
          name: P extends { in: "header" }
            ? Lowercase<N> extends "accept" | "content-type" | "authorization"
              ? `OpenAPI ignores a header parameter named ${N}`
              : ParamsName<N> extends true
                ? Reserved<N>
                : string
            : ParamsName<N> extends true
              ? Reserved<N>
              : string;
          schema: P extends { schema: infer S } ? CheckParameterSchema<S> : OtherParameter["schema"];
        },
        "a parameter"
      >
    : Keys<P, Parameter, "a parameter">;

type CheckPathSchema<S> = S extends { type: "integer" }
  ? Keys<S, IntegerParameterSchema, "an integer parameter">
  : S extends { type: "string" }
    ? Keys<S, Annotations & { type: "string" }, "a path parameter's string">
    : Keys<S, { type: "integer" | "string" }, "a path parameter">;

type CheckParameterSchema<S> = S extends { type: "integer" }
  ? Keys<S, IntegerParameterSchema, "an integer parameter">
  : S extends { type: "boolean" }
    ? Keys<S, Annotations & { type: "boolean" }, "a boolean parameter">
    : S extends { type: "string" }
      ? Keys<S, Annotations & { type: "string"; minLength?: number; maxLength?: number }, "a string parameter">
      : Keys<S, { type: "integer" | "boolean" | "string" }, "a parameter">;

// A request body is a $ref to an object component, as JSON.
type CheckBody<B, C> = Keys<
  B,
  {
    required: true;
    description?: string;
    "x-body-limit"?: number;
    content: B extends { content: infer X }
      ? Keys<
          X,
          {
            "application/json": X extends { "application/json": infer M }
              ? Keys<
                  M,
                  {
                    schema: M extends { schema: infer S }
                      ? Keys<
                          S,
                          Annotations & {
                            $ref: `#/components/schemas/${ObjectNames<C> & string}` | "a body is a $ref to an object component";
                          },
                          "a body's $ref"
                        >
                      : Ref;
                  },
                  "a media type"
                >
              : never;
          },
          "a request body's content"
        >
      : RequestBody["content"];
  },
  "a request body"
>;

type Single<K, All = K> = [K] extends [never] ? false : K extends unknown ? ([Exclude<All, K>] extends [never] ? true : false) : never;

type CheckSecurity<S, Schemes extends string> = S extends readonly []
  ? S
  : S extends readonly [infer R]
    ? readonly [
        Single<keyof R> extends true
          ? { [K in keyof R]: K extends Schemes ? readonly [] : "no such scheme in components.securitySchemes" }
          : "one scheme per requirement is supported"
      ]
    : "one security requirement is supported, not alternatives";
