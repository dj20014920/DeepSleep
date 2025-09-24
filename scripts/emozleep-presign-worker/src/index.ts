export default {
  async fetch(request: Request, env: any) {
    const url = new URL(request.url);
    if (url.pathname !== "/presign") {
      return new Response("Not Found", { status: 404 });
    }
    const file = url.searchParams.get("file");
    if (!file || !/^[a-z0-9._\-]+\.gguf$/i.test(file)) {
      return new Response("invalid file", { status: 400 });
    }

    // Optional simple auth (env.PRESIGN_TOKEN). If set, require Bearer token.
    const token = env.PRESIGN_TOKEN as string | undefined;
    if (token) {
      const auth = request.headers.get("Authorization");
      if (auth !== `Bearer ${token}`) {
        return new Response("unauthorized", { status: 401 });
      }
    }

    const cdnBase = env.CDN_BASE || "https://cdn.emozleep.space/models";
    const finalUrl = `${cdnBase}/${file}`;

    const mode = url.searchParams.get("mode") || "json";
    if (mode === "redirect") {
      return new Response(null, { status: 302, headers: { Location: finalUrl } });
    }
    return new Response(JSON.stringify({ url: finalUrl }), {
      status: 200,
      headers: {
        "content-type": "application/json; charset=utf-8",
        "cache-control": "no-store",
      },
    });
  },
} satisfies ExportedHandler;
