# PII in Logs

When writing `console.log`, `console.warn`, `console.error`, or any logging call that includes user-provided data:

- **Mask email addresses** — show `u***@domain.com`, never the full address
- **Mask names** — show initials or first letter only
- **Mask phone numbers** — show last 4 digits only
- **Never log form submissions, request bodies, or full user records**

This applies to all log levels including debug and warn. "It's just a warning" is not an exception — logs are retained, searched, and accessed broadly.

## Common mistake

Writing a quick debug/warning log during business logic and interpolating user data without thinking about it:

```ts
// WRONG — PII in a "harmless" warning
console.warn(`[email] Skipping send to suppressed address: ${to}`);

// CORRECT
console.warn(`[email] Skipping send to suppressed address: ${maskEmail(to)}`);
```

The fix is always a mask function, never omitting the log entirely (the log is useful, the PII is not).
