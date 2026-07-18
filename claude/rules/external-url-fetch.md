# External URL Fetch

When the server fetches a URL that originates from an external payload (webhook body, API response, user input, queue message):

- **Validate the hostname** against an expected domain pattern before fetching
- This applies even when the payload has been authenticated (signature verification, HMAC, JWT) — authentication proves who sent the message, not that every URL inside it is safe
- Reject and log if the hostname doesn't match

## Common mistake

Trusting a URL inside a verified payload because the payload itself is authentic:

```ts
// WRONG — payload is signed, but SubscribeURL points anywhere
const message = await verifySnsSignature(body);
await fetch(message.SubscribeURL); // SSRF

// CORRECT — validate destination before fetching
const host = new URL(message.SubscribeURL).hostname;
if (!/^sns\.[a-z0-9-]+\.amazonaws\.com$/.test(host)) {
  return new Response("Invalid URL domain", { status: 400 });
}
await fetch(message.SubscribeURL);
```

Authentication and authorization are separate concerns. A signed message proves origin; it does not prove every embedded URL is safe to fetch from a server context.
