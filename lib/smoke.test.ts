import { describe, expect, it } from "vitest";
import { z } from "zod";

describe("test infrastructure", () => {
  it("runs TypeScript tests with zod available", () => {
    expect(z.string().uuid().safeParse("not-a-uuid").success).toBe(false);
  });
});
